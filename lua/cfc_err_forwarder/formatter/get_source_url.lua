local publicGamemodes = {
  base = true,
  sandbox = true,
  terrortown = true
}
return function(source, line)
  local sourceSpl = string.Split(source, "/")
  local root = sourceSpl[1]
  local mainDir = sourceSpl[2]
  if root == "gamemodes" then
    return "https://github.com/Facepunch/garrysmod/blob/master/garrysmod/" .. tostring(source) .. "#L" .. tostring(line)
  end
  if root ~= "addons" then
    return 
  end
  local fetchPath = "addons/" .. tostring(mainDir) .. "/.git/FETCH_HEAD", "GAME"
  if not (file.Exists(fetchPath, "GAME")) then
    return 
  end
  local content = file.Read(fetchPath, "GAME")
  local firstLine = string.Split(content, "\n")[1]
  local _, branch, repo
  _, _, branch, repo = string.find(firstLine, "branch '(.+)' of (.+)$")
  repo = string.Replace(repo, "https://", "")
  repo = string.Replace(repo, "http://", "")
  repo = string.Replace(repo, ":", "/")
  repo = string.Replace(repo, ".git", "")
  local repoSpl = string.Split(repo, "/")
  local host = repoSpl[1]
  local owner = repoSpl[2]
  local project = repoSpl[3]
  local finalPath = table.concat(sourceSpl, "/", 3, #sourceSpl)
  finalPath = finalPath .. "#L" .. tostring(line)
  local finalURL = string.format("https://%s/%s/%s/blob/%s/%s", host, owner, project, branch, finalPath)
  return finalURL
end
