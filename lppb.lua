local consts = {
    desegmentation = {
        DISABLED = 1,
        C2S = 2,
        S2C = 3,
        BIDIRECTIONAL = 4,
    },
    format = {
        prefix_endianness = {},
        prefix_length = {},
    },
    prefix_endianness = {
        BIG = 1,
        LITTLE = 2,
    },
    prefix_length = {
        BYTE = 1,
        SHORT = 2,
        INT = 4,
        LONG = 8,
    },
}

consts.format.prefix_endianness[consts.prefix_endianness.BIG] = '>'
consts.format.prefix_endianness[consts.prefix_endianness.LITTLE]= '<'

consts.format.prefix_length[consts.prefix_length.BYTE] = 'B'
consts.format.prefix_length[consts.prefix_length.SHORT] = 'H'
consts.format.prefix_length[consts.prefix_length.INT] = 'I'
consts.format.prefix_length[consts.prefix_length.LONG] = 'L'

local port = 0
local prefs = {
    desegmentation = {
        { 1, 'Disabled', consts.desegmentation.DISABLED },
        { 2, 'Client-to-server', consts.desegmentation.C2S },
        { 3, 'Server-to-client', consts.desegmentation.S2C },
        { 4, 'Bidirectional', consts.desegmentation.BIDIRECTIONAL },
    },
    prefix_endianness = {
        { 1, 'Big', consts.prefix_endianness.BIG },
        { 2, 'Little', consts.prefix_endianness.LITTLE },
    },
    prefix_length = {
        { 1, 'Byte',  consts.prefix_length.BYTE },
        { 2, 'Short',  consts.prefix_length.SHORT },
        { 3, 'Int',  consts.prefix_length.INT, },
        { 4, 'Long',  consts.prefix_length.LONG },
    },
}

local lppb = Proto('lppb', 'Length-prefixed protocol buffers');

lppb.fields.length = ProtoField.uint64('lppb.length', 'Length')
lppb.prefs.port = Pref.uint('TCP port', 0, 'Default-decode packets originating from this port')
lppb.prefs.type = Pref.string('Message type', '', 'Fully-qualified message type name to use when decoding')
lppb.prefs.prefix_length = Pref.enum('Prefix length', consts.prefix_length.INT, 'Length prefix length', prefs.prefix_length, false)
lppb.prefs.prefix_endianness = Pref.enum('Prefix endianness', consts.prefix_endianness.BIG, 'Length prefix endianness', prefs.prefix_endianness, false)
lppb.prefs.skip_bytes = Pref.uint('Skip bytes', 0, 'Number of bytes to skip after length prefix')
lppb.prefs.desegmentation = Pref.enum('Desegmentation', consts.desegmentation.DISABLED, 'Reassemble packets accross TCP segment boundaries', prefs.desegmentation, false)
lppb.prefs_changed = function()
    if port == lppb.prefs.port then
        return
    end

    if port ~= 0 then
        DissectorTable.get('tcp.port'):remove(port, lppb)
    end

    port = lppb.prefs.port

    if port ~= 0 then
        DissectorTable.get('tcp.port'):add(port, lppb)
    end
end

function desegment(proto, pinfo)
    if proto.prefs.desegmentation == consts.desegmentation.DISABLED then
        return false
    elseif proto.prefs.desegmentation == consts.desegmentation.BIDIRECTIONAL then
        return true
    end

    if proto.prefs.desegmentation == consts.desegmentation.C2S then
        return pinfo.dst_port == port
    else
        return pinfo.src_port == port
    end
end

function message_offset()
    return lppb.prefs.prefix_length + lppb.prefs.skip_bytes
end

function message_length(tvb)
    local prefix_endianness = lppb.prefs.prefix_endianness
    local prefix_length = lppb.prefs.prefix_length
    local format = consts.format.prefix_endianness[prefix_endianness] .. consts.format.prefix_length[prefix_length]

    return Struct.unpack(format, tvb:raw(0, prefix_length))
end

function pdu_length(tvb, pinfo, tree)
    return message_offset() + message_length(tvb)
end

function dissect_message(tvb, pinfo, tree)
    local length = message_length(tvb)
    local offset = message_offset()
    local subtree = tree:add(lppb, tvb:range(), 'Length-prefixed protocol buffer message')

    subtree:add(lppb.fields.length, tvb:range(0, lppb.prefs.prefix_length), UInt64.new(length))

    pinfo.private['pb_msg_type'] = 'message,' .. lppb.prefs.type

    return Dissector.get('protobuf'):call(tvb:range(offset, length):tvb(), pinfo, subtree)
end

function lppb.dissector(tvb, pinfo, tree)
    dissect_tcp_pdus(tvb,
                     tree,
                     message_offset(),
                     pdu_length,
                     dissect_message,
                     desegment(lppb, pinfo))
end
