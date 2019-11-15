local ErrorForwarder
do
  local _class_0
  local _base_0 = {
    count_queue = function(self)
      return table.Count(self.queue)
    end,
    queue_is_empty = function(self)
      return self:count_queue() == 0
    end,
    error_is_queued = function(self, error_string)
      return self.queue[error_string] ~= nil
    end,
    add_error_to_queue = function(self, is_runtime, full_error, source_file, source_line, error_string, stack)
      local new_error = {
        isRunTime = is_runtime,
        fullError = full_error,
        sourceFile = source_file,
        sourceLine = source_line,
        errorString = error_string,
        stack = stack,
        occurredAt = os.time(),
        count = 1
      }
      self.logger:info("Inserting error into queue: " .. tostring(error_string))
      self.queue[error_string] = new_error
    end,
    remove_error_from_queue = function(self, error_string)
      self.queue[error_string] = nil
    end,
    increment_existing_error = function(self, error_string)
      self.queue[error_string]["count"] = self.queue[error_string]["count"] + 1
    end,
    receive_lua_error = function(self, is_runtime, full_error, source_file, source_line, error_string, stack)
      self.logger:debug("Received Lua Error: " .. tostring(error_string))
      if self:error_is_queued(error_string) then
        return self:increment_existing_error(error_string)
      end
      return self:add_error_to_queue(is_runtime, full_error, source_file, source_line, error_string, stack)
    end,
    forward_error = function(self, error_object, on_success, on_failure)
      self.logger:info("Sending error object..")
      return self.webhooker_interface:send("forward-errors", error_object, on_success, on_failure)
    end,
    forward_all_errors = function(self)
      for error_string, error_data in pairs(self.queue) do
        self.logger:debug("Processing queued error: " .. tostring(error_string))
        local success
        success = function(message)
          return self:on_success(error_string, message)
        end
        local failure
        failure = function(failure)
          return self:on_failure(error_string, failure)
        end
        self:forward_error(error_data, success, failure)
      end
    end,
    groom_queue = function(self)
      self.logger:info("Grooming Error Queue of size " .. tostring(self:count_queue()))
      if self:queue_is_empty() then
        return 
      end
      return self:forward_all_errors()
    end,
    on_success = function(self, error_string, message)
      self.logger:info("Successfully sent error: " .. tostring(error_string))
      return self:remove_error_from_queue(error_string)
    end,
    on_failure = function(self, error_string, failure)
      self.logger:error("Failed to send error!\n" .. tostring(failure))
      return self:remove_error_from_queue(error_string)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, logger, webhooker_interface)
      self.logger = logger
      self.webhooker_interface = webhooker_interface
      self.queue = { }
    end,
    __base = _base_0,
    __name = "ErrorForwarder"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  ErrorForwarder = _class_0
  return _class_0
end
