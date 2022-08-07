#!/usr/bin/bash

MSGS=$(cat msgs)

mangle() {
    echo $1 | tr . _
}

cat << EOF > kakele_prefs.lua
local prefs = {}

prefs.message_type = {
    MESSAGE_NONE = 1,
EOF

i=1
for MSG in $MSGS; do
    MSG_MANGLED=$(mangle "$MSG")
    echo "    MESSAGE_${MSG_MANGLED} = $i," >> kakele_prefs.lua
    i=$((i + 1))
done

cat << EOF >> kakele_prefs.lua
}

prefs.message_names = {
    '',
EOF

i=1
for MSG in $MSGS; do
    echo "    '${MSG}'," >> kakele_prefs.lua
    i=$((i + 1))
done

cat << EOF >> kakele_prefs.lua
}

prefs.messages = {
    { 1, 'None', prefs.message_type.MESSAGE_NONE },
EOF

i=1
for MSG in $MSGS; do
    echo "    { $i, '$MSG', prefs.message_type.MESSAGE_$(mangle "$MSG") }," >> kakele_prefs.lua
    i=$((i + 1))
done

cat << EOF >> kakele_prefs.lua
}

function prefs:populate(proto)
    proto.prefs.type_c2s = Pref.enum('Request type',
                                     prefs.message_type.MESSAGE_NONE,
                                     'Message type to decode for client requests',
                                     prefs.messages,
                                     false)

    proto.prefs.type_s2c = Pref.enum('Response type',
                                     prefs.message_type.MESSAGE_NONE,
                                     'Message type to decode for server responses',
                                     prefs.messages,
                                     false)
end

function prefs:type_c2s(proto)
    return self.message_names[proto.prefs.type_c2s + 1]
end

function prefs:type_s2c(proto)
    return self.message_names[proto.prefs.type_s2c + 1]
end

return prefs
EOF
