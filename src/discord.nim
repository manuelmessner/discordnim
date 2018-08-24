# Wish i could split this up a bit, but errors because cyclical includes
include restapi
import marshal, json, cgi, discordobjects, endpoints,
       websocket/shared, asyncdispatch, asyncnet, uri, zip/zlib
       
# Gateway op codes
{.hint[XDeclaredButNotUsed]: off.}
const 
    opDispatch              = 0
    opHeartbeat             = 1
    opIdentify              = 2
    opStatusUpdate          = 3
    opVoiceStateUpdate      = 4
    opVoiceServerPing       = 5
    opResume                = 6
    opReconnect             = 7
    opRequestGuildMembers   = 8
    opInvalidSession        = 9
    opHello                 = 10
    opHeartbeatAck          = 11


# Permissions 
const
    permCreateInstantInvite* = 0x00000001
    permKickMembers* = 0x00000002
    permBanMembers* = 0x00000004
    permAdministrator* = 0x00000008
    permManageChannels* = 0x00000010
    permManageGuild* = 0x00000020
    permAddReactions* = 0x00000040
    permViewAuditLogs* = 0x00000080
    permPrioritySpeaker* = 0x00000100
    permViewChannel* = 0x00000400
    permSendMessages* = 0x00000800
    permSendTTSMessage* = 0x00001000
    permManageMessages* = 0x00002000
    permEmbedLinks* = 0x00004000
    permAttachFiles* = 0x00008000
    permReadMessageHistory* = 0x00010000
    permMentionEveryone* = 0x00020000
    permUseExternalEmojis* = 0x00040000
    permVoiceConnect* = 0x00100000
    permVoiceSpeak* = 0x00200000
    permVoiceMuteMembers* = 0x00400000
    permVoiceDeafenMemebrs* = 0x00800000
    permVoiceMoveMembers* = 0x01000000
    permUseVAD* = 0x02000000
    permChangeNickname* = 0x04000000
    permManageNicknames* = 0x08000000
    permManageRoles* = 0x10000000
    permManageWebhooks* = 0x20000000
    permManageEmojis* = 0x40000000
    permAllText* = permViewChannel or 
        permSendMessages or 
        permSendTTSMessage or 
        permManageMessages or
        permEmbedLinks or 
        permAttachFiles or
        permReadMessageHistory or
        permMentionEveryone
    permAllVoice* = permVoiceConnect or
        permVoiceSpeak or
        permVoiceMuteMembers or
        permVoiceMoveMembers or
        permVoiceDeafenMemebrs or
        permUseVAD
    permAllChannel* = permAllText or
        permAllVoice or
        permCreateInstantInvite or
        permManageRoles or
        permManageChannels or
        permAddReactions or
        permViewAuditLogs
    permAll* = permAllChannel or
        permKickMembers or
        permBanMembers or
        permManageGuild or
        permAdministrator


method getGateway(s: Shard): Future[tuple[url: string, sc: int]] {.base, async, gcsafe.} =
    var url = gateway()
    let res = await s.request(url, "GET", url, "application/json", "", 0)
    let body = await res.body()
    type Temp2 = object
        total: int
        remaining: int
        reset_after: int
    type Temp = object
        url: string 
        shards: int
        session_start_limit: Temp2
    let t = marshal.to[Temp](body)
    result = (t.url, t.shards)

type 
    UpdateStatusData = object
        since: int # idle_since
        game: Game
        afk: bool
        status: string

method updateStreamingStatus*(s: Shard, idle: int = 0, game: string, url: string = "", status: string = "online") {.base, async, gcsafe.} =
    ## Updates the ``Playing ...`` message of the current user.
    if s.connection.sock.isClosed(): return
    var data = UpdateStatusData(status: status, afk: false)
    if idle > 0:
        data.since = idle
    
    if game != "":
        var gt = 0
        if url != "":
            gt = 1
        data.game = Game(name: game, `type`: gt)
        if url != "": data.game.url = url 

    let payload = %*{
        "op": 3,
        "d": data
    }
    await s.connection.sock.sendText($payload, true)

method updateStatus*(s: Shard, idle: int = 0, game: string = "") {.base, gcsafe, async, inline.} =
    ## Updates the ``Playing ...`` status
    asyncCheck s.updateStreamingStatus(idle, game, "")

# I'd like to make this prettier if at all possible
method initEvents(s: Shard) {.base, gcsafe.} = 
    s.addHandler(channel_create, proc(s: Shard, p: ChannelCreate) = return) 
    s.addHandler(channel_update, proc(s: Shard, p: ChannelUpdate) = return)
    s.addHandler(channel_delete, proc(s: Shard, p: ChannelDelete) = return)
    s.addHandler(channel_pins_update, proc(s: Shard, p: ChannelPinsUpdate) = return)
    s.addHandler(guild_create, proc(s: Shard, p: GuildCreate) = return)
    s.addHandler(guild_update, proc(s: Shard, p: GuildUpdate) = return)
    s.addHandler(guild_delete, proc(s: Shard, p: GuildDelete) = return)
    s.addHandler(guild_ban_add, proc(s: Shard, p: GuildBanAdd) = return)
    s.addHandler(guild_ban_remove, proc(s: Shard, p: GuildBanRemove) = return)
    s.addHandler(guild_emojis_update, proc(s: Shard, p: GuildEmojisUpdate) = return)
    s.addHandler(guild_integrations_update, proc(s: Shard, p: GuildIntegrationsUpdate) = return)
    s.addHandler(guild_member_add, proc(s: Shard, p: GuildMemberAdd) = return)
    s.addHandler(guild_member_update, proc(s: Shard, p: GuildMemberUpdate) = return)
    s.addHandler(guild_member_remove, proc(s: Shard, p: GuildMemberRemove) = return)
    s.addHandler(guild_members_chunk, proc(s: Shard, p: GuildMembersChunk) = return)
    s.addHandler(guild_role_create, proc(s: Shard, p: GuildRoleCreate) = return)
    s.addHandler(guild_role_update, proc(s: Shard, p: GuildRoleUpdate) = return)
    s.addHandler(guild_role_delete, proc(s: Shard, p: GuildRoleDelete) = return)
    s.addHandler(message_create, proc(s: Shard, p: MessageCreate) = return)
    s.addHandler(message_update, proc(s: Shard, p: MessageUpdate) = return)
    s.addHandler(message_delete, proc(s: Shard, p: MessageDelete) = return)
    s.addHandler(message_delete_bulk, proc(s: Shard, p: MessageDeleteBulk) = return)
    s.addHandler(message_reaction_add, proc(s: Shard, p: MessageReactionAdd) = return)
    s.addHandler(message_reaction_remove, proc(s: Shard, p: MessageReactionRemove) = return)
    s.addHandler(message_reaction_remove_all, proc(s: Shard, p: MessageReactionRemoveAll) = return)
    s.addHandler(presence_update, proc(s: Shard, p: PresenceUpdate) = return)
    s.addHandler(typing_start, proc(s: Shard, p: TypingStart) = return)
    s.addHandler(user_update, proc(s: Shard, p: UserUpdate) = return)
    s.addHandler(voice_state_update, proc(s: Shard, p: VoiceStateUpdate) = return)
    s.addHandler(voice_server_update, proc(s: Shard, p: VoiceServerUpdate) = return)
    s.addHandler(on_resume, proc(s: Shard, p: Resumed) = return)
    s.addHandler(on_ready, proc(s: Shard, p: Ready) = return)
    s.addHandler(webhooks_update, proc(s: Shard, p: WebhooksUpdate) = return)

proc newShard*(token: string): Shard {.gcsafe.} =
    if token == "":
        raise newException(Exception, "No token")

    result = Shard(
        token: token,
        globalRL: newRateLimiter(),
        mut: Lock(),
        handlers: initTable[EventType, pointer](),
        compress: false, 
        limiter: newRateLimiter(),
        sequence: 0,
        cache: Cache(
            users: initTable[string, User](),
            members: initTable[string, GuildMember](),
            guilds: initTable[string, Guild](), 
            channels: initTable[string, Channel](),
            roles: initTable[string, Role]()
        )
    )

    result.initEvents()

    let gateway = waitFor result.getGateway()
    result.gateway = gateway.url.strip&"/"&GATEWAYVERSION


type
  IdentifyError* = object of Exception

method handleDispatch(s: Shard, event: string, data: JsonNode) {.async, gcsafe, base.} =
    case event:
        of "READY":
            let payload = newReady(data)
            s.session_id = payload.session_id
            s.cache.version = payload.v
            s.cache.me = payload.user
            s.cache.users[payload.user.id] = payload.user 
            for channel in payload.private_channels: 
                s.cache.channels[channel.id] = channel
                
            s.cache.ready = payload
            cast[proc(_: Shard, r: Ready) {.cdecl.}](s.handlers[on_ready])(s, payload)
        of "RESUMED":
            let payload = newResumed(data)
            cast[proc(_: Shard, r: Resumed) {.cdecl.}](s.handlers[on_resume])(s, payload)
        of "CHANNEL_CREATE":
            let payload = newChannelCreate(data)
            if s.cache.cacheChannels: s.cache.channels[payload.id] = payload
            cast[proc(_: Shard, r: ChannelCreate) {.cdecl.}](s.handlers[channel_create])(s, payload)
        of "CHANNEL_UPDATE":
            let payload = newChannelUpdate(data)
            if s.cache.cacheChannels: s.cache.updateChannel(payload)
            cast[proc(_: Shard, r: ChannelUpdate) {.cdecl.}](s.handlers[channel_update])(s, payload)
        of "CHANNEL_DELETE":
            let payload = newChannelDelete(data)
            if s.cache.cacheChannels: s.cache.removeChannel(payload.id)
            cast[proc(_: Shard, r: ChannelDelete) {.cdecl.}](s.handlers[channel_delete])(s, payload)
        of "CHANNEL_PINS_UPDATE":
            let payload = newChannelPinsUpdate(data)
            cast[proc(_: Shard, r: ChannelPinsUpdate) {.cdecl.}](s.handlers[channel_pins_update])(s, payload)
        of "GUILD_CREATE":
            let payload = newGuildCreate(data)
            if s.cache.cacheGuilds: s.cache.guilds[payload.id] = payload
            cast[proc(_: Shard, r: GuildCreate) {.cdecl.}](s.handlers[guild_create])(s, payload)
        of "GUILD_UPDATE":
            let payload = newGuildUpdate(data)
            if s.cache.cacheGuilds: s.cache.updateGuild(payload)
            cast[proc(_: Shard, r: GuildUpdate) {.cdecl.}](s.handlers[guild_update])(s, payload)
        of "GUILD_DELETE":
            let payload = newGuildDelete(data)
            if s.cache.cacheGuilds: s.cache.removeGuild(payload.id)
            cast[proc(_: Shard, r: GuildDelete) {.cdecl.}](s.handlers[guild_delete])(s, payload)
        of "GUILD_BAN_ADD":
            let payload = newGuildBanAdd(data)
            cast[proc(_: Shard, r: GuildBanAdd) {.cdecl.}](s.handlers[guild_ban_add])(s, payload)
        of "GUILD_BAN_REMOVE":
            let payload = newGuildBanRemove(data)
            cast[proc(_: Shard, r: GuildBanRemove) {.cdecl.}](s.handlers[guild_ban_remove])(s, payload)
        of "GUILD_EMOJIS_UPDATE":
            let payload = newGuildEmojisUpdate(data)
            cast[proc(_: Shard, r: GuildEmojisUpdate) {.cdecl.}](s.handlers[guild_emojis_update])(s, payload)
        of "GUILD_INTEGRATIONS_UPDATE":
            let payload = newGuildIntegrationsUpdate(data)
            cast[proc(_: Shard, r: GuildIntegrationsUpdate) {.cdecl.}](s.handlers[guild_integrations_update])(s, payload)
        of "GUILD_MEMBER_ADD":
            let payload = newGuildMemberAdd(data)
            if s.cache.cacheGuildMembers: s.cache.addGuildMember(payload)
            cast[proc(_: Shard, r: GuildMemberAdd) {.cdecl.}](s.handlers[guild_member_add])(s, payload)
        of "GUILD_MEMBER_UPDATE":
            let payload = newGuildMemberUpdate(data)
            if s.cache.cacheGuildMembers: s.cache.updateGuildMember(payload)
            cast[proc(_: Shard, r: GuildMemberUpdate) {.cdecl.}](s.handlers[guild_member_update])(s, payload)
        of "GUILD_MEMBER_REMOVE":
            let payload = newGuildMemberRemove(data)
            if s.cache.cacheGuildMembers: s.cache.removeGuildMember(payload)
            cast[proc(_: Shard, r: GuildMemberRemove) {.cdecl.}](s.handlers[guild_member_remove])(s, payload)
        of "GUILD_MEMBERS_CHUNK":
            let payload = newGuildMembersChunk(data)
            cast[proc(_: Shard, r: GuildMembersChunk) {.cdecl.}](s.handlers[guild_members_chunk])(s, payload)
        of "GUILD_ROLE_CREATE":
            let payload = newGuildRoleCreate(data)
            if s.cache.cacheRoles: s.cache.roles[payload.role.id] = payload.role
            cast[proc(_: Shard, r: GuildRoleCreate) {.cdecl.}](s.handlers[guild_role_create])(s, payload)
        of "GUILD_ROLE_UPDATE":
            let payload = newGuildRoleUpdate(data)
            if s.cache.cacheRoles: s.cache.updateRole(payload.role)
            cast[proc(_: Shard, r: GuildRoleUpdate) {.cdecl.}](s.handlers[guild_role_update])(s, payload)
        of "GUILD_ROLE_DELETE":
            let payload = newGuildRoleDelete(data)
            if s.cache.cacheRoles: s.cache.removeRole(payload.role_id)
            cast[proc(_: Shard, r: GuildRoleDelete) {.cdecl.}](s.handlers[guild_role_delete])(s, payload)
        of "MESSAGE_CREATE":
            let payload = newMessageCreate(data)
            cast[proc(_: Shard, r: MessageCreate) {.cdecl.}](s.handlers[message_create])(s, payload)
        of "MESSAGE_UPDATE":
            let payload = newMessageUpdate(data)
            cast[proc(_: Shard, r: MessageUpdate) {.cdecl.}](s.handlers[message_update])(s, payload)
        of "MESSAGE_DELETE":
            let payload = newMessageDelete(data)
            cast[proc(_: Shard, r: MessageDelete) {.cdecl.}](s.handlers[message_delete])(s, payload)
        of "MESSAGE_DELETE_BULK":
            let payload = newMessageDeleteBulk(data)
            cast[proc(_: Shard, r: MessageDeleteBulk) {.cdecl.}](s.handlers[message_delete_bulk])(s, payload)
        of "MESSAGE_REACTION_ADD":
            let payload = newMessageReactionAdd(data)
            cast[proc(_: Shard, r: MessageReactionAdd) {.cdecl.}](s.handlers[message_reaction_add])(s, payload)
        of "MESSAGE_REACTION_REMOVE":
            let payload = newMessageReactionRemove(data)
            cast[proc(_: Shard, r: MessageReactionRemove) {.cdecl.}](s.handlers[message_reaction_remove])(s, payload)
        of "MESSAGE_REACTION_REMOVE_ALL":
            let payload = newMessageReactionRemoveAll(data)
            cast[proc(_: Shard, r: MessageReactionRemoveAll) {.cdecl.}](s.handlers[message_reaction_remove_all])(s, payload)
        of "PRESENCE_UPDATE":
            var payload = newPresenceUpdate(data)
            cast[proc(_: Shard, r: PresenceUpdate) {.cdecl.}](s.handlers[presence_update])(s, payload)
        of "TYPING_START":
            let payload = newTypingStart(data)
            cast[proc(_: Shard, r: TypingStart) {.cdecl.}](s.handlers[typing_start])(s, payload)
        of "USER_UPDATE":
            let payload = newUserUpdate(data)
            cast[proc(_: Shard, r: UserUpdate) {.cdecl.}](s.handlers[user_update])(s, payload)
        of "VOICE_STATE_UPDATE":
            let payload = newVoiceStateUpdate(data)
            cast[proc(_: Shard, r: VoiceStateUpdate) {.cdecl.}](s.handlers[voice_state_update])(s, payload)
        of "VOICE_SERVER_UPDATE":
            let payload = newVoiceServerUpdate(data)
            cast[proc(_: Shard, r: VoiceServerUpdate) {.cdecl.}](s.handlers[voice_server_update])(s, payload)
        of "WEBHOOKS_UPDATE":
            let payload = newWebhooksUpdate(data)
            cast[proc(_: Shard, r: WebhooksUpdate) {.cdecl.}](s.handlers[webhooks_update])(s, payload)
        of "USER_SETTINGS_UPDATE": discard
        of "PRESENCES_REPLACE": discard
        else:
            echo "Unknown websocket event :: " & event & "\c\L" & $data

method identify(s: Shard) {.async, gcsafe, base.} =
    var properties = %*{
        "$os": system.hostOS,
        "$browser": "Discordnim v"&VERSION,
        "$device": "Discordnim v"&VERSION,
        "$referrer": "",
        "$referring_domain": ""
    }
    
    var payload = %*{
        "op": opIDENTIFY,
        "d": %*{
            "token": s.token,
            "properties": properties,
            "compress": s.compress
        }
    }
    
    if s.shardCount > 1: 
        if s.shardID >= s.shardCount:
            raise newException(IdentifyError, "ShardID has to be lower than ShardCount")
        payload["shard"] = %*[s.shardID, s.shardCount]

    try:
        await s.connection.sock.sendText($payload, true)
    except:
        echo "Error sending identify packet\n" & getCurrentExceptionMsg()

method resume(s: Shard) {.async, gcsafe, base.} =
    let payload = %*{
        "token": s.token,
        "session_id": s.session_id,
        "seq": s.sequence
    }
    await s.connection.sock.sendText($payload, true)

method reconnect(s: Shard) {.async, gcsafe, base.} =
    await s.connection.close()
    try:
        s.connection = await newAsyncWebsocket("gateway.discord.gg", Port 443, "/"&GATEWAYVERSION, ssl = true)
    except:
        raise getCurrentException()
    s.sequence = 0
    s.session_ID = ""
    await s.identify()

method shouldResumeSession(s: Shard): bool {.gcsafe, inline, base.} = (not s.invalidated) and (not s.suspended)

method setupHeartbeats(s: Shard) {.async, gcsafe, base.} =
    while not s.stop and not s.connection.sock.isClosed:
        var hb = %*{"op": opHeartbeat, "d": s.sequence}
        try:
            await s.connection.sock.sendText($hb, true) 
            await sleepAsync s.interval 
        except:
            if s.stop: break
            echo "Something happened when sending heartbeat through the websocket connection"
            echo getCurrentExceptionMsg()
            break

proc sessionHandleSocketMessage(s: Shard): Future[void]  =
    result = newFuture[void]("sessionHandleSocketMessage")
    waitFor s.identify()

    var tres: Future[tuple[opcode: Opcode, data: string]]
    var res: tuple[opcode: Opcode, data: string]
    var errors = 0
    while not isClosed(s.connection.sock) and not s.stop:
        let tres = s.connection.sock.readData(true)
        if tres.failed():
            s.connection.sock.close()
            result.fail(tres.error)
            break

        try:
            res = waitFor tres
        except:
            echo "Encountered an error while waiting for websocket data"
            echo getCurrentExceptionMsg()
            errors.inc
            if errors >= 5:
                result.fail(newException(Exception, "Too many errors while listening to websocket"))
                break
            continue

        if s.compress:
            if res.opcode == Opcode.Binary:
                let t = zlib.uncompress(res.data)
                if t == nil:
                    echo "Failed to uncompress data and I'm not sure why. Sorry."
                else: res.data = t
                
        var data: JsonNode
        try: 
            data = parseJson(res.data) 
        except: 
            errors.inc
            echo "Error while parsing json: " & res.data 
            continue
         
        if data["s"].kind != JNull:
            let i = data["s"].num.int
            s.sequence = i

        case data["op"].num
        of opDispatch:
            let event = data["t"].str
            asyncCheck s.handleDispatch(event, data["d"])
        of opHello:
            if s.shouldResumeSession():
                waitFor s.resume()
            else:
                s.suspended = false
                let interval = data["d"].fields["heartbeat_interval"].num.int
                s.interval = interval
                asyncCheck s.setupHeartbeats()
        of opHeartbeat:
            let hb = %*{"op": opHeartbeat, "d": s.sequence}
            waitFor s.connection.sock.sendText($hb, true)
        of opHeartbeatAck:
            # TODO :: Should probably check for HEARTBEAT_ACKs and close the connection if we don't get one
            discard
        of opInvalidSession:
            s.sequence = 0
            s.session_ID = ""
            s.invalidated = true 
            if data["d"].kind == JBool and data["d"].bval == false:
                waitFor s.identify()
        of opReconnect:
            s.suspended = true
            waitFor s.reconnect()
        else:
            echo "Unknown opcode :: ", $data
        
        #poll()

    echo "connection closed\ncode: ", res.opcode, "\ndata: ", res.data, "\nerrors: ", errors
    s.suspended = true
    s.stop = true
    if not s.connection.sock.isClosed:
        s.connection.sock.close()
    echo "Disconnected..."
    if not result.failed():
        result.complete()
    else:
        raise result.error
    cast[proc(s: Shard){.cdecl.}](s.handlers[on_disconnect])(s)

method disconnect*(s: Shard) {.gcsafe, base, async.} =
    ## Disconnects a shard
    s.stop = true
    s.cache.clear()
    await s.connection.close() # Does not seem to send the close code properly?

method startSession*(s: Shard) {.base, async.} =
    ## Connects a Shard
    if s.connection != nil and not s.connection.sock.isClosed():
        echo "Shard is already connected"
        return
    s.suspended = true
    try:
        let wsurl = parseUri(s.gateway)
        s.connection = await newAsyncWebsocket(
                wsurl.hostname, 
                if wsurl.scheme == "wss": Port(443) else: Port(80), 
                wsurl.path&GATEWAYVERSION, 
                ssl = true, 
                useragent = "Discordnim (https://github.com/Krognol/discordnim v"&VERSION&")"
            )
    except:
        echo getCurrentExceptionMsg()
        s.stop = true
        return
    try:
        await sessionHandleSocketMessage(s)
    except:
        echo "Something happened in the socket listening :: ", getCurrentExceptionMsg()