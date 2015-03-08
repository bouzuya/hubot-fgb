# Description
#   A Hubot script to support FGB
#
# Configuration:
#   HUBOT_FGB_BACKLOG_SPACE_ID
#   HUBOT_FGB_PROJECTS
#
# Commands:
#   None
#
# Author:
#   bouzuya <m@bouzuya.net>
#

{Promise} = require 'es6-promise'
parseConfig = require 'hubot-config'
newRequests = require '../review-requests'
newSpace = require '../space'

config = parseConfig 'fgb',
  backlogSpaceId: null
  projects: '{}'
  users: '{}'

sendToChat = (robot, { room, user, message }) ->
  m = (if user? then "<@#{user}> " else '') + message
  e = {}
  e.room = room if room?
  robot.send e, m

onIssueCreated = (robot, space, w) ->
  projectKey = w.project.projectKey
  project = space.getProject projectKey
  unless project?
    robot.logger.warning 'hubot-fgb: unknown project key: ' + projectKey
    return
  issueKey = "#{project.getKey()}-#{w.content.key_id}"
  issueUrl = "https://#{space.getId()}.backlog.jp/view/#{issueKey}"
  summary = w.content.summary
  description = w.content.description
  username = w.createdUser.name
  room = project.getRoom()
  message = """
  #{username} が新しい課題「#{issueKey} #{summary}」を追加したみたい。
  #{description}
  #{issueUrl}
  """
  sendToChat robot, { room, message }

onIssueUpdated = (robot, space, w, requests) ->
  projectKey = w.project.projectKey
  project = space.getProject projectKey
  unless project?
    robot.logger.warning 'hubot-fgb: unknown project key: ' + projectKey
    return
  issueKey = "#{project.getKey()}-#{w.content.key_id}"
  issueUrl = "https://#{space.getId()}.backlog.jp/view/#{issueKey}"
  summary = w.content.summary
  description = w.content.description
  username = w.createdUser.name
  comment = w.content.comment.content
  room = project.getRoom()
  resolved = w.content.changes.some (i) ->
    i.field is 'status' and i.new_value is '3'
  message = """
  #{username} が課題「#{issueKey} #{summary}」を更新したみたい。
  #{comment}
  #{issueUrl}
  """
  sendToChat robot, { room, message }
  if resolved
    user = space.getUser username
    requests.add room, user, issueKey
    message = "#{issueKey} を誰かにレビュー依頼しないの？"
    sendToChat robot, { room, user, message }

module.exports = (robot) ->
  robot.logger.debug 'hubot-fgb: load config: ' + JSON.stringify config
  space = newSpace config
  requests = newRequests()

  robot.router.post '/hubot/fgb/backlog/webhook', (req, res) ->
    webhook = req.body
    if webhook.type is 1 # issue created
      onIssueCreated robot, space, webhook
    else if webhook.type is 2 # issue updated
      onIssueUpdated robot, space, webhook, requests
    else
      return if webhook.type <= 17 # max webhook.type
      robot.logger.warning "hubot-fgb: unknown webhook type: #{webhook.type}"
    res.send 'OK'