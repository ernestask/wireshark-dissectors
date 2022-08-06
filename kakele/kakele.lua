local kakele = Proto('kakele', 'Kakele');
-- 2-byte length prefix and NUL
local offset = 3
local pb_dissector = Dissector.get('protobuf')
local port = 7001
local prefs = require('kakele_prefs')

kakele.fields.length = ProtoField.uint16('kakele.length', 'Length')
kakele.fields.separator = ProtoField.bytes('kakele.nul', 'Separator')
kakele.fields.message = ProtoField.bytes('kakele.message', 'Message')

prefs:populate(kakele)

function get_message_len(tvb, pinfo, tree)
    return offset + tvb:range(0, 2):uint()
end

function is_client_message(pinfo)
    return pinfo.dst_port == port
end

function dissect_message(tvb, pinfo, tree)
    local length = tvb:range(0, 2):uint()
    local type = prefs:msg_type(kakele)
    local subtree = tree:add(kakele, tvb:range(), 'Kakele message', type)

    subtree:add(kakele.fields.length, length)
    subtree:add(kakele.fields.separator, tvb:range(2, 1))

    local msg_range = tvb:range(offset, length)
    local msg_tree = subtree:add(kakele.fields.message, msg_range)

    pinfo.private['pb_msg_type'] = 'message,' .. type

    return pb_dissector:call(msg_range:tvb(),
                             pinfo,
                             msg_tree)
end

function kakele.dissector(tvb, pinfo, tree)
    -- Client packets are segmented
    local desegment = is_client_message(pinfo)

    dissect_tcp_pdus(tvb,
                     tree,
                     3,
                     get_message_len,
                     dissect_message,
                     desegment)
end

DissectorTable.get('tcp.port'):add(port, kakele)
