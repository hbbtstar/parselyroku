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
  widthString = Str(screenSize["w"]).Trim()
  heightString = Str(screenSize["h"]).Trim()
  parselyTracker.screenSize = widthString + "x" +  heightString + "|" + widthString + "x" + heightString + "|" + "32"  
  parselyTracker.screenSize = parselyTracker.screenSize.Trim()
  ' single point of on/off for analytics
  parselyTracker.enable = false
  parselyTracker.asyncReqById = {}    ' Since we async HTTP metric requests, hold onto objects so they don't go out of scope (and get killed)
  parselyTracker.asyncMsgPort = CreateObject("roMessagePort")

  parselyTracker.debug = false

  'set global attributes
  parselyTracker.video = CreateObject("RoSGNode", "Video")
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
  if metadata.author = invalid then metadata.authors = m.parselyTracker.apikey
  if metadata.tags = invalid then metadata.tags = {}
  if metadata.image_url = invalid then metadata.image_url = "" else metadata.image_url = metadata.image_url
  metadata.video_platform = "roku"
  if m.parselyTracker.debug
    ? "[Parsely] Action: " + action
    ? "[Parsely] APIKey: " + m.parselyTracker.apikey
    ? "[Parsely] video id: " + Str(metadata.link)
    ? "[Parsely] title" + metadata.title
  end if 
  
  ' Roku has no concept of URL, so just make some url that will make it through the pipeline: okay if it has no metadata
  pageUrl = "http://" + m.parselyTracker.apikey + "/rokuplayer"
  date = CreateObject("roDateTime")
  pixel_params = {
    action: action,
    idsite: m.parselyTracker.apikey,
    url: Box(pageUrl),
    urlref: "",
    data: m.parselyTracker.data,
    screen: m.parselyTracker.screenSize,
    date: date.ToISOString(),
    metadata: metadata
    
  }
  if inc > 0
    pixel_params.inc = inc.ToStr()
  end if
  parselyTrackPixel(pixel_params)
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
  full_params = "?" + "data" + "=" + FormatJSON(hit_params.data).encodeURIComponent()
  if hit_params.metadata <> invalid then
      full_params = full_params + "&" + "metadata" + "=" + FormatJSON(hit_params.metadata).encodeURIComponent()
  end if

  for each param in hit_params
    if param <> "metadata" and param <> "data" then
    full_params = full_params + "&" + param + "=" + hit_params[param].encodeURIComponent()
    end if
  end for
    full_params = full_params
      
    'New xfer obj needs to be made each request and ref held on to per https://sdkdocs.roku.com/display/sdkdoc/ifUrlTransfer
    request = CreateObject("roURLTransfer")
    request.SetMessagePort(m.parselyTracker.asyncMsgPort)
    

    reqString = baseUrl + full_params
    reqString = reqString.Trim()
    print reqString
    request.SetUrl(reqString)
    didSend = request.AsyncGetToString()
    requestId = request.GetIdentity().ToStr()
    m.parselyTracker.asyncReqById[requestId] = request
    print "[Parsely] request initiated ("+requestId+")";reqString
    print "[Parsely] pending req";getParselyPendingRequestsMap()

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