-- curl -i -X POST -d 'payload={"text": "Hello, this is some text.\nThis is more text."}' http://yourmattermost.com/hooks/xxx-generatedkey-xxx

local tools = require "tools"
local cjson = require "cjson"

local mattermost_url = tools.get_env_variable_with_arg('BITBUCKET_MATTERMOST_URL', 'room', nil)
local mattermost_user = tools.get_env_variable_with_arg('BITBUCKET_MATTERMOST_USER', 'user', 'bitbucket')

local data_ = tools.get_ngx_data()
local data = cjson.decode(data_)
local message = nil

local push = data.push
if push then
    local actor = data.actor.display_name
    local actor_href = data.actor.links.html.href
    local avatar_href = data.actor.links.avatar.href
    local avatar_message = ''
    if avatar_href then
        avatar_message = '![embedded image](' .. avatar_href .. ') '
    end
    local repository = data.repository
    local repo = repository.full_name
    local repo_href = repository.links.html.href
    local new_commit = push.changes[1].new
    local target = new_commit.target
    local branch_name = new_commit.name
    local branch_href = new_commit.links.html.href
    local href = target.links.html.href
    --local commit_message, num_rep = string.gsub(target.message, "\n", "")
    local commit_message = target.message
    message = avatar_message .. '**[' .. repo .. '](' .. href .. ')**/*[' .. branch_name .. '](' .. branch_href .. ')* :: New commit from [' .. actor .. '](' .. actor_href .. '): ' .. '\n```\n' .. commit_message .. '\n```'
end

local pullrequest = data.pullrequest
if pullrequest then
    local actor = data.actor.display_name
    local repo = pullrequest.destination.repository.full_name
    local repo_href = pullrequest.destination.repository.links.html.href
    local href = pullrequest.links.html.href
    local title = pullrequest.title
    message = '**[' .. repo .. '](' .. href .. ')** :: New pull request from ' .. actor .. ': ' .. href .. ' (*' .. title .. '*)'
end

local comment = data.comment
if comment then
    local content = comment.content.raw
    local comment_href = comment.links.html.href
    local repository = data.repository
    local repo = repository.full_name
    local repo_href = repository.links.html.href
    local user = comment.user.display_name
    local user_href = comment.user.links.html.href

    -- now question is whether the comment is for pull request or for commit
    local commit = comment.commit
    if commit then
        local commit_hash = comment.commit.hash
        local commit_href = comment.commit.links.html.href
        local user = comment.user.display_name
        local user_href = comment.user.links.html.href
        message = '**[' .. repo .. '](' .. repo_href .. ')**/*[' .. commit_hash .. '](' .. commit_href .. ')* :: [New comment](' .. comment_href .. ') from [' .. user .. '](' .. user_href .. '):\n' .. content
    end

    local pull_request = comment.pullrequest
    if pull_request then
        local title = pull_request.title
        local pull_request_href = pullrequest.links.html.href
        message = '**[' .. repo .. '](' .. repo_href .. ')**/*[PR ' .. title .. '](' .. pull_request_href .. ')* :: [New comment](' .. comment_href .. ') from [' .. user .. '](' .. user_href .. '):\n' .. content
    end
end

if not message then
    message = 'This is not implemented yet: ' .. data_
end

ngx.say('message: ', message)

local res, err = tools.send_mattermost_message(
  mattermost_url,
  message,
  username
)

ngx.say(cjson.encode({status='ok'}))
