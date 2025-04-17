--[[
    ToasterGen Spin

    Copyright (C) 2025 Clifton Toaster Reid <cliftontreid@duck.com>

    This library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with this library. If not, see <https://www.gnu.org/licenses/>.
]]

---@class ZipkinSpan
---@field id string Unique 64bit identifier encoded as 16 lowercase hex characters.
---@field traceId string Unique 64 or 128bit identifier encoded as 16 or 32 lowercase hex characters.
---@field parentId string | nil Unique 64bit identifier encoded as 16 lowercase hex characters.
---@field name string | nil The logical operation this span represents in lowercase (e.g. rpc method).
---@field timestamp number | nil Epoch microseconds of the start of this span, possibly absent if incomplete.
---@field duration number | nil Duration in microseconds of the critical path, if known. Durations of less than one are rounded up. Duration of children can be longer than their parents due to asynchronous operations.
---@field kind "CLIENT" | "SERVER" | "PRODUCER" | "CONSUMER" When present, kind clarifies timestamp, duration and remoteEndpoint. When absent, the span is local or incomplete. Unlike client and server, there is no direct critical path latency relationship between producer and consumer spans.
---@field localEndpoint ZipkinEndpoint | nil The network context of a node in the service graph
---@field remoteEndpoint ZipkinEndpoint | nil The network context of a node in the service graph
---@field annotations ZipkinAnnotation[] | nil Associates events that explain latency with the time they happened.
---@field tags table<string, string> | nil Adds context to a span, for search, viewing and analysis. For example, a key "your_app.version" would let you lookup traces by version. A tag "sql.query" isn't searchable, but it can help in debugging when viewing a trace.

---@class ZipkinAnnotation
---@field timestamp number Epoch microseconds of this event. For example, 1502787600000000 corresponds to 2017-08-15 09:00 UTC This value should be set directly by instrumentation, using the most precise value possible. For example, gettimeofday or multiplying epoch millis by 1000.
---@field value string Usually a short tag indicating an event, like "error". While possible to add larger data, such as garbage collection details, low cardinality event names both keep the size of spans down and also are easy to search against.

---@class ZipkinEndpoint
---@field serviceName string | nil Lower-case label of this node in the service graph, such as "favstar". Leave absent if unknown.
---@field ipv4 string | nil The text representation of the primary IPv4 address associated with this connection. Ex. 192.168.99.100 Absent if unknown.
---@field ipv6 string | nil The text representation of the primary IPv6 address associated with a connection. Ex. 2001:db8::c001 Absent if unknown.
---@field port number | nil Depending on context, this could be a listen port or the client-side of a socket. Absent if unknown. Please don't set to zero.

local expect = require("cc.expect").expect
local Logger = require("src.log")

---@type string | nil
local TEMPO_URL = nil
---@type ZipkinSpan[]
local spans = {}

local Trace = {}
local SpanMethods = {}

--- Returns the current time since epoch in microseconds.
---@return number current timestamp in microseconds
local function getTimestamp()
    local time = os.epoch() -- Returns milliseconds since epoch
    local microseconds = time * 1000
    return microseconds
end

--- Sets the parentId of the span.
---@param self ZipkinSpan the span instance
---@param parentId string Unique 64-bit identifier encoded as 16 hex characters.
---@return ZipkinSpan the span instance
function SpanMethods:setParentId(parentId)
    expect(1, parentId, "string")

    self.parentId = string.lower(parentId)
    return self
end

--- Sets the name of the span operation.
---@param self ZipkinSpan the span instance
---@param name string Logical operation name in lowercase.
---@return ZipkinSpan the span instance
function SpanMethods:setName(name)
    expect(1, name, "string")

    self.name = string.lower(name)
    return self
end

--- Sets the kind of the span (CLIENT, SERVER, PRODUCER, or CONSUMER).
---@param self ZipkinSpan the span instance
---@param kind string The span kind (CLIENT, SERVER, PRODUCER, or CONSUMER).
---@return ZipkinSpan the span instance
function SpanMethods:setKind(kind)
    expect(1, kind, "string")

    if kind ~= "CLIENT" and kind ~= "SERVER" and kind ~= "PRODUCER" and kind ~= "CONSUMER" then
        error("Invalid kind. Must be one of CLIENT, SERVER, PRODUCER, or CONSUMER.")
    end
    self.kind = string.upper(kind)
    return self
end

--- Internal helper to set or clear an endpoint on the span.
---@param self ZipkinSpan the span instance
---@param endpointKey "localEndpoint" | "remoteEndpoint" field to set
---@param serviceName string|nil Service name in lowercase or nil to clear
---@param ipv4 string|nil IPv4 address or nil to clear
---@param ipv6 string|nil IPv6 address or nil to clear
---@param port number|nil Port number or nil to clear
---@return ZipkinSpan the span instance
local function _setEndpoint(self, endpointKey, serviceName, ipv4, ipv6, port)
    -- If all are nil, set the specified endpoint field to nil
    if not serviceName and not ipv4 and not ipv6 and not port then
        self[endpointKey] = nil
        return self
    end

    -- Create or reuse the endpoint table
    local endpoint = self[endpointKey] or {}
    self[endpointKey] = endpoint

    -- Assign values, converting strings to lowercaseP
    endpoint.serviceName = serviceName and string.lower(serviceName) or nil
    endpoint.ipv4 = ipv4 and string.lower(ipv4) or nil
    endpoint.ipv6 = ipv6 and string.lower(ipv6) or nil
    endpoint.port = port or nil

    return self
end

--- Sets the local endpoint of the span.
---@param self ZipkinSpan the span instance
---@param serviceName string|nil Service name
---@param ipv4 string|nil IPv4 address
---@param ipv6 string|nil IPv6 address
---@param port number|nil Port number
---@return ZipkinSpan the span instance
function SpanMethods:setLocalEndpoint(serviceName, ipv4, ipv6, port)
    expect(1, serviceName, "string", "nil")
    expect(2, ipv4, "string", "nil")
    expect(3, ipv6, "string", "nil")
    expect(4, port, "number", "nil")
    return _setEndpoint(self, "localEndpoint", serviceName, ipv4, ipv6, port)
end

--- Sets the remote endpoint of the span.
---@param self ZipkinSpan the span instance
---@param serviceName string|nil Service name
---@param ipv4 string|nil IPv4 address
---@param ipv6 string|nil IPv6 address
---@param port number|nil Port number
---@return ZipkinSpan the span instance
function SpanMethods:setRemoteEndpoint(serviceName, ipv4, ipv6, port)
    expect(1, serviceName, "string", "nil")
    expect(2, ipv4, "string", "nil")
    expect(3, ipv6, "string", "nil")
    expect(4, port, "number", "nil")
    return _setEndpoint(self, "remoteEndpoint", serviceName, ipv4, ipv6, port)
end

--- Adds an annotation event to the span with the current timestamp.
---@param self ZipkinSpan the span instance
---@param value string Short tag value for the annotation
---@return ZipkinSpan the span instance
function SpanMethods:addAnnotation(value)
    expect(1, value, "string")

    local timestamp = getTimestamp()

    if not self.annotations then
        self.annotations = {}
    end

    table.insert(self.annotations, { timestamp = timestamp, value = value })
    return self
end

--- Adds a key-value tag to the span for search and analysis.
---@param self ZipkinSpan the span instance
---@param key string Tag key
---@param value string Tag value
---@return ZipkinSpan the span instance
function SpanMethods:addTag(key, value)
    expect(1, key, "string")
    expect(2, value, "string")

    if not self.tags then
        self.tags = {}
    end

    self.tags[key] = value
    return self
end

--- Ends the span by calculating and setting its duration.
---@param self ZipkinSpan the span instance
---@return ZipkinSpan the span instance
---@throws error if the span was not started
function SpanMethods:endSpan()
    if not self.timestamp then
        error("Span has not started yet.")
    end

    if not self.duration then
        local endTime = getTimestamp()
        self.duration = endTime - self.timestamp
    end

    return self
end

--- Generates a random 64-bit ID as 16 lowercase hexadecimal characters.
---@return string generated hex ID
function Trace.rndID()
    local id = math.random(0, 0xFFFFFFFFFFFFFFFF)
    return string.format("%016x", id)
end

--- Creates a new ZipkinSpan with unique IDs and start timestamp.
---@return ZipkinSpan a new span instance
function Trace.new()
    local timestamp = getTimestamp()
    local span = {
        id = Trace.rndID(),
        traceId = Trace.rndID(),
        parentId = nil,
        name = nil,
        timestamp = timestamp,
        duration = nil,
        kind = nil,
        localEndpoint = nil,
        remoteEndpoint = nil,
        annotations = nil,
        tags = nil,
    }

    -- Set the metatable to allow method chaining
    setmetatable(span, { __index = SpanMethods })

    return span
end

--- Sets the Tempo URL for sending spans.
---@param url string The Tempo URL
---@return string The configured Tempo URL
function Trace.setTempoURL(url)
    expect(1, url, "string")
    local valid, reason = http.checkURL(url)
    if not valid then
        Logger.error("Invalid Tempo URL: " .. reason)
        error("Invalid Tempo URL: " .. reason)
    end

    TEMPO_URL = url
    return TEMPO_URL
end

--- Adds a span to the list of spans to be sent to Tempo.
---@param span ZipkinSpan The span to add
---@return ZipkinSpan the span instance
function Trace.addSpan(span)
    expect(1, span, "table")

    if not span.id or not span.traceId then
        error("Span must have an id and traceId.")
    end

    if not TEMPO_URL then
        error("Tempo URL is not set. Use Trace.setTempoURL(url) to set it.")
    end

    -- Add the span to the list of spans
    table.insert(spans, span)

    return span
end

--- Sends the collected spans to the configured Tempo URL.
---@return boolean success True if the spans were sent successfully or if there were no spans to send, false otherwise.
function Trace.send()
    if not TEMPO_URL then
        Logger.error("Tempo URL is not set. Cannot send spans.")
        return false
    end

    if #spans == 0 then
        return true
    end

    local jsonPayload = textutils.serializeJSON(spans)
    local headers = { ["Content-Type"] = "application/json" }

    local reason = http.post(TEMPO_URL, jsonPayload, headers)

    if reason.getResponseCode() ~= 202 then
        return false
    end

    -- Clear the spans list after successful sending
    spans = {}
    return true
end

return Trace
