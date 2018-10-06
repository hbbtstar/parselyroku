Function initParsely(apikey As String) As Void
  parselyTracker = CreateObject("roAssociativeArray")

  ' Set up some static stuff
  parselyTracker.baseUrl = "http://srv.pixel.parsely.com/plogger/"
  parselyTracker.apikey = apikey
  parselyTracker.data = CreateObject("roAssociativeArray")
  

  ' Default session params
  app_info = CreateObject("roAppInfo")
  device = createObject("roDeviceInfo")
  
  ' get some things Parsely will need
  parselyTracker.data.parsely_site_uuid = device.GetRIDA()
  screenSize = device.GetDisplaySize()
  parselyTracker.screenSize = screenSize["w"] + screenSize["h"] + "|" + screenSize["w"] + screenSize["h"] + "|" + "32"  

  ' single point of on/off for analytics
  parselyTracker.enable = false
  parselyTracker.asyncReqById = {}    ' Since we async HTTP metric requests, hold onto objects so they don't go out of scope (and get killed)
  parselyTracker.asyncMsgPort = CreateObject("roMessagePort")

  parselyTracker.debug = false

  'set global attributes
  m.parselyTracker = parselyTracker
End Function

Function enableParsely(enable As Boolean) As Void
  m.parselyTracker.enable = enable
End Function

Function getParselyPendingRequestsMap() as Object
  return m.parselyTracker.asyncReqById
End Function

Function setParselyDebug(enable As Boolean) As Void
  m.parselyTracker.debug = enable
End Function

Function parselyTrackAction(action As String, metadata={} as Object, inc=0 as Integer) As Void
  if metadata.title = invalid then metadata.title = ""
  if metadata.section = invalid then metadata.section = "Uncategorized"
  if metadata.author = invalid then metadata.authors = Box(m.parselyTracker.apikey).Escape()
  if metadata.tags = invalid then metadata.tags = {}
  if metadata.image_url = invalid then metadata.image_url = "" else metadata.image_url = Box(metadata.image_url).Escape()
  metadata.video_platform = "roku"
  if m.parselyTracker.debug
    ? "[Parsely] Action: " + action
    ? "[Parsely] APIKey: " + parselyTracker.apikey
    ? "[Parsely] video id: " + video_id
    ? "[Parsely] title" + title
    ? "[Parsely] author: " + author
    ? "[Parsely] section: " + section
  end if 
  
  ' Roku has no concept of URL, so just make some url that will make it through the pipeline: okay if it has no metadata
  pageUrl = "http://" + m.parselyTracker.apikey + "/rokuplayer"
  date = CreateObject("roDateTime")
  pixel_params = {
    action: action,
    idsite: Box(m.parselyTracker.apikey).Escape(),
    url: Box(pageUrl).Escape(),
    urlref: "",
    data: m.parselyTracker.data,
    screen: m.parselyTracker.screenSize,
    date: Box(date.ToISOString()).Escape(),
    metadata: metadata
    
  }
  if inc > 0
    pixel_params.inc = inc
  end if
  parselySendPixel(pixel_params)
End Function

Function parselyTrackVideoStart(metadata={} as Object) As Void
  parselyTrackAction("videostart", metadata)
End Function

Function parselyTrackVideoHeartbeat(metadata={} as Object, inc=10) As Void
  parselyTrackAction("vheartbeat", metadata, inc)
End Function

Function parselyTrackPixel(hit_params As Object) As Void
  if m.parselyTracker.enable <> true then
    if m.parselyTracker.debug
      ? "[Parsely] disabled. Skipping GET"
    end if
    return
  endif

  baseUrl = m.parselyTracker.baseUrl

  for each param in hit_params
    full_params = full_params + "&" + param + "=" + hit_params[param]
  end for

    'New xfer obj needs to be made each request and ref held on to per https://sdkdocs.roku.com/display/sdkdoc/ifUrlTransfer
    request = CreateObject("roURLTransfer")
    request.SetMessagePort(m.parselyTracker.asyncMsgPort)

    reqString = baseUrl + "?" + full_params
    request.SetUrl(reqString)

    
    didSend = request.AsyncToFromString()
    requestId = request.GetIdentity().ToStr()
    m.parselyTracker.asyncReqById[requestId] = request

    if m.parselyTracker.debug
      ? "[Parsely] request initiated ("+requestId+")";reqString
      ? "[Parsely] pending req";getParselyPendingRequestsMap()
    end if

  parselyCleanupAsyncReq()

End Function

' Garbage collect async requests that have completed
Function parselyCleanupAsyncReq()
  For Each rid in m.parselyTracker.asyncReqById
    msg = m.parselyTracker.asyncMsgPort.GetMessage()
    if type(msg) = "roUrlEvent" and msg.GetInt() = 1    '1=xfer complete. We don't care about GetResponseCode() or GetFailureReason()
        requestId = msg.GetSourceIdentity().ToStr()   'Because we are sharing same port, get the request id
        m.parselyTracker.asyncReqById.Delete(requestId)
    end if
  End For

  if m.parselyTracker.debug
    ? "[Parsely] parselyCleanupAsyncReq pending ";getParselyPendingRequestsMap()
  end if
End Function