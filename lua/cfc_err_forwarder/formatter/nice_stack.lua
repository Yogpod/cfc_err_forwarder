return function(data)
  local indent = 2
  local lines = {
    data.fullError or "<unknown error>"
  }
  local stack = data.stack
  for i = 1, #stack do
    indent = indent + 1
    local item = stack[i]
    local lineNumber = item.currentline
    local src = item.short_src or item.source or "<unknown source>"
    local name = item.name or ""
    if #name == 0 then
      name = "<unknown>"
    end
    local spacing = string.rep(" ", indent)
    table.insert(lines, tostring(spacing) .. tostring(i) .. ".  " .. tostring(name) .. " - " .. tostring(src) .. ":" .. tostring(lineNumber))
  end
  return table.concat(lines, "\n")
end
