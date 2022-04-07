import Count from table

osTime = os.time
rawset = rawset
rawget = rawget
istable = istable

removeCyclic = (tbl, found={}) ->
    return if found[tbl]
    found[tbl] = true

    for k, v in pairs tbl
        continue unless istable v

        if found[v]
            print "Found cyclic table, key: #{k} | value: #{v} | table: #{tbl}"
            tbl[k] = nil
        else
            removeCyclic v, found

stripStack = (tbl) ->
    for _, stackobj in pairs tbl
        stackobj.locals = nil
        stackobj.upvalues = nil
        stackobj.activelines = nil

class ErrorForwarder
    new: (logger, webhooker, groomInterval) =>
        @logger = logger
        @webhooker = webhooker
        @groomInterval = groomInterval
        @queue = {}

    countQueue: => Count @queue

    errorIsQueued: (fullError) => rawget( @queue, fullError ) ~= nil

    addPlyToObject: (errorStruct, ply) =>
        rawset errorStruct, "player", {
            playerName: ply\Name! or "Invalid Player",
            playerSteamID: ply\SteamID! or "Invalid Player"
        }

        errorStruct

    queueError: (isRuntime, fullError, sourceFile, sourceLine, errorString, stack, ply) =>
        count = 1
        occurredAt = osTime!
        isClientside = ply ~= nil

        newError = {
            :count
            :errorString
            :fullError
            :isRuntime
            :occurredAt
            :sourceFile
            :sourceLine
            :stack
            :isClientside
            reportInterval: @groomInterval
        }

        if isClientside
            newError = @addPlyToObject newError, ply

        @logger\info "Inserting error into queue: '#{fullError}'"

        rawset @queue, fullError, newError

    unqueueError: (fullError) =>
        thisErr = rawget @queue, fullError

        if thisErr
            for k in pairs thisErr
                rawset thisErr, k, nil

        rawset @queue, fullError, nil

    incrementError: (fullError) =>
        thisErr = rawget @queue, fullError
        count = rawget thisErr, "count"

        rawset thisErr, "count", count + 1
        rawset thisErr, "occurredAt", osTime!

    receiveError: (isRuntime, fullError, sourceFile, sourceLine, errorString, stack, ply) =>
        if @errorIsQueued fullError
            return @incrementError fullError

        @queueError isRuntime, fullError, sourceFile, sourceLine, errorString, stack, ply


    logErrorInfo: (isRuntime, fullError, sourceFile, sourceLine, errorString, stack) =>
        debug = @logger\debug

        debug "Is Runtime: #{isRuntime}"
        debug "Full Error: #{fullError}"
        debug "Source File: #{sourceFile}"
        debug "Source Line: #{sourceLine}"
        debug "Error String: #{errorString}"

    receiveSVError: (isRuntime, fullError, sourceFile, sourceLine, errorString, stack) =>
        @logger\info "Received Serverside Lua Error: #{errorString}"
        @logErrorInfo isRuntime, fullError, sourceFile, sourceLine, errorString, stack

        @receiveError isRuntime, fullError, sourceFile, sourceLine, errorString, stack

    receiveCLError: (ply, fullError, sourceFile, sourceLine, errorString, stack) =>
        if not ply or ply\IsPlayer!
            ply = "Invalid player"
            @logger\info "Received Clientside Lua Error from Invalid Player: #{errorString}"
        else
            @logger\info "Received Clientside Lua Error for #{ply\SteamID!} (#{ply\Name!}): #{errorString}"
        @logErrorInfo nil, fullError, sourceFile, sourceLine, errorString, stack

        @receiveError isRuntime, fullError, sourceFile, sourceLine, errorString, stack, ply

    generateJSONStruct: (errorStruct) =>
        stripStack errorStruct.stack
        { json: util.TableToJSON errorStruct }

    forwardError: (errorStruct, onSuccess, onFailure) =>
        @logger\info "Sending error object.."
        data = @generateJSONStruct errorStruct

        @webhooker\send "forward-errors", data, onSuccess, onFailure

    forwardErrors: =>
        for errorString, errorData in pairs @queue
            @logger\debug "Processing queued error: #{errorString}"

            onSuccess = (message) -> @onSuccess errorString, message
            onFailure = (failure) -> @onFailure errorString, failure

            success, err = pcall ->
                @forwardError errorData, onSuccess, onFailure

            continue if success

            onFailure err

    groomQueue: =>
        count = @countQueue!
        return if count == 0

        @logger\info "Grooming Error Queue of size: #{count}"

        @forwardErrors!

    onSuccess: (fullError, message) =>
        @logger\info "Successfully sent error", fullError
        @unqueueError fullError

    onFailure: (fullError, failure) =>
        @logger\error "Failed to send error!", failure
        @unqueueError fullError
