#!/usr/bin/python3

import argparse
from google.protobuf.descriptor_pb2 import FileDescriptorSet
from jinja2 import Template
from typing import BinaryIO, List

def get_messages(ds_file: BinaryIO) -> List[str]:
    descriptor_set = FileDescriptorSet()

    descriptor_set.ParseFromString(ds_file.read())

    return [f'{f.package}.{m.name}'
            for f in descriptor_set.file
            for m in f.message_type]

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generate kakele_prefs.lua')

    parser.add_argument('descriptor_set',
                        nargs=1,
                        type=argparse.FileType('rb'),
                        metavar='DESCRIPTOR_SET')

    args = parser.parse_args()
    messages = get_messages(args.descriptor_set[0])
    template = Template('''\
local prefs = {
    message_name = {
        c2s = {
            '',
            {%- for req in requests %}
            '{{ req }}',
            {%- endfor %}
        },
        s2c = {
            '',
            {%- for res in responses %}
            '{{ res }}',
            {%- endfor %}
        },
    },
    message_type = {
        c2s = {
            MESSAGE_NONE = 1,
            {%- for req in requests %}
            MESSAGE_{{ req | replace('.', '_') }} = {{ loop.index + 1 }},
            {%- endfor %}
        },
        s2c = {
            MESSAGE_NONE = 1,
            {%- for res in responses %}
            MESSAGE_{{ res | replace('.', '_') }} = {{ loop.index + 1 }},
            {%- endfor %}
        },
    }
}

prefs.message = {
    c2s = {
        { 1, 'None', prefs.message_type.c2s.MESSAGE_NONE },
        {%- for req in requests %}
        { {{ loop.index + 1 }}, prefs.message_name.c2s[{{ loop.index + 1 }}], prefs.message_type.c2s.MESSAGE_{{ req | replace('.', '_') }} },
        {%- endfor %}
    },
    s2c = {
        { 1, 'None', prefs.message_type.s2c.MESSAGE_NONE },
        {%- for res in responses %}
        { {{ loop.index + 1 }}, prefs.message_name.s2c[{{ loop.index + 1 }}], prefs.message_type.s2c.MESSAGE_{{ res | replace('.', '_') }} },
        {%- endfor %}
    },
}

function prefs:populate(proto)
    proto.prefs.type_c2s = Pref.enum('Request type',
                                     prefs.message_type.c2s.MESSAGE_NONE,
                                     'Message type to decode for client requests',
                                     prefs.message.c2s,
                                     false)

    proto.prefs.type_s2c = Pref.enum('Response type',
                                     prefs.message_type.s2c.MESSAGE_NONE,
                                     'Message type to decode for server responses',
                                     prefs.message.s2c,
                                     false)
end

function prefs:type_c2s(proto)
    return self.message_name.c2s[proto.prefs.type_c2s]
end

function prefs:type_s2c(proto)
    return self.message_name.s2c[proto.prefs.type_s2c]
end

return prefs
'''
    )

    with open('kakele_prefs.lua', 'w') as f:
        f.write(template.render(
            requests=list(filter(
                lambda m: m.endswith('Request') or not m.endswith('Response'),
                messages,
            )),
            responses=list(filter(
                lambda m: m.endswith('Response') or not m.endswith('Request'),
                messages,
            )),
        ))
