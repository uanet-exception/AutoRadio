#!/usr/bin/liquidsoap
# Allow root
settings.init.allow_root.set(true)

settings.server.telnet.set(true)
settings.server.telnet.port.set(1234)
settings.server.telnet.bind_addr.set("0.0.0.0")
settings.harbor.bind_addrs.set(["0.0.0.0"])
# settings.log.level.set(4)

# Set environments if empty
if getenv("ICECAST_SOURCE_PASSWORD") == "" then
    setenv("ICECAST_SOURCE_PASSWORD", "hackme")
end
if getenv("ICECAST_STREAM_BITRATE") == "" then
    setenv("ICECAST_STREAM_BITRATE", "128")
end
if getenv("STREAM_NAME") == "" then
    setenv("STREAM_NAME", "Radio")
end
if getenv("STREAM_DESC") == "" then
    setenv("STREAM_DESC", "Our selection of music")
end
if getenv("STREAM_MOUNTPOINT") == "" then
    setenv("STREAM_MOUNTPOINT", "live")
end
if getenv("DJ_USERNAME") == "" then
    setenv("DJ_USERNAME", "source")
end
if getenv("DJ_PASSWORD") == "" then
    setenv("DJ_PASSWORD", "hackme")
end
if getenv("DJ_MOUNTPOINT") == "" then
    setenv("DJ_MOUNTPOINT", "/dj-on-air-live")
end

headers = ref([])

def on_connect(new_headers) =
    headers := new_headers
end

def add_dj_metadata(metadata) =
    headers = !headers
    name = headers["Ice-Name"]
    desc = headers["Ice-Description"]

    if (name != "" and desc != "") then
        list.add(("title", "#{name} (#{desc})"), metadata)
    elsif (name != "") then
        list.add(("title", "#{name}"), metadata)
    elsif (desc != "") then
        list.add(("title", "#{desc}"), metadata)
    else
        list.add(("title", "Live DJ Connected"), metadata)
    end
end

live = input.harbor(
    getenv("DJ_MOUNTPOINT"),
    icy=true,
    replay_metadata=true,
    max=2048.,
    port=8888,
    buffer=0.0,
    on_connect=on_connect,
    user=getenv("DJ_USERNAME"),
    password=getenv("DJ_PASSWORD")
)
live = map_metadata(add_dj_metadata, live)

autodj = crossfade(
    duration=3.0,
    smart=true,
    blank.eat(
        start_blank=true,
        max_blank=1.0,
        threshold=-45.0,
        playlist(
            mode="randomize",
            reload=1,
            reload_mode="rounds",
            "/music"
        )
    )
)

radio = mksafe(fallback(track_sensitive=false, [live, autodj]))

# Output
output.icecast(
    %mp3(
        bitrate=int_of_string(getenv("ICECAST_STREAM_BITRATE")),
        id3v2=true
    ),
    name=getenv("STREAM_NAME"),
    description=getenv("STREAM_DESC"),
    url=getenv("STREAM_URL"),
    mount=getenv("STREAM_MOUNTPOINT"),
    password=getenv("ICECAST_SOURCE_PASSWORD"),
    host="icecast",
    genre=getenv("STREAM_GENRE"),
    port=8000,
    encoding="UTF-8",
    radio
)
