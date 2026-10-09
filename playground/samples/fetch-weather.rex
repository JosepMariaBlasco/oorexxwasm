/* The weather in a city, with a small window: ADDRESS DOM builds it,        */
/* ADDRESS FETCH asks Open-Meteo.  Classic Rexx commands only: no objects,  */
/* no JavaScript.  Type a city and press Enter (or the button); the cross   */
/* in the title bar ends the program.                                       */
address dom
'NEW "Weather" AS win'
'CREATE - h3 "Weather in any city"'
'CREATE form div'
'form: CLASS row'
'form: FIELD city'
'city: ATTR placeholder "City (e.g. Barcelona)"'
'form: BUTTON show "Show" SHOW'
'city: ON enter SHOW'
'CREATE place h2'
'CREATE now p'
'CREATE days table'
'CREATE note p'
'note: STYLE font-size 12px'
'note: STYLE opacity 0.7'
'city: VALUE Barcelona'
'city: FOCUS'
call show "Barcelona"

do forever
  'WAIT INTO ev'
  select
    when ev~name = "SHOW" then do
      'city: VALUE INTO city'
      if city~strip \== "" then call show city~strip
    end
    when ev~name = "CLOSE" then leave
    otherwise nop
  end
end
say "Bye."
exit

-- look the city up, then fill the window with its weather
show: procedure
  use arg city
  address dom
  'show: DISABLE'
  'note: TEXT "Asking Open-Meteo..."'
  address fetch
  "GET https://geocoding-api.open-meteo.com/v1/search?count=1&language=en&name="encode(city)
  if rc \= 0 then do; call trouble "the geocoding service answered" rc; return; end
  "JSON INTO found"
  if \found~hasIndex("results") then do; call trouble "no city called" city; return; end
  place = found["results"][1]
  lat = place["latitude"]; lon = place["longitude"]
  "GET https://api.open-meteo.com/v1/forecast?latitude="lat"&longitude="lon ||,
      "&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code" ||,
      "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum" ||,
      "&timezone=auto&forecast_days=5"
  if rc \= 0 then do; call trouble "the forecast service answered" rc; return; end
  "JSON INTO w"
  now = w["current"]; daily = w["daily"]
  rows = .array~of(.array~of("Day", "Sky", "Min", "Max", "Rain"))
  do i = 1 to daily["time"]~items
    day = daily["time"][i]
    rows~append(.array~of(date("W", day, "I")~left(3) day~right(5), sky(daily["weather_code"][i]),,
      format(daily["temperature_2m_min"][i],, 1) "°C", format(daily["temperature_2m_max"][i],, 1) "°C",,
      format(daily["precipitation_sum"][i],, 1) "mm"))
  end
  title = place["name"]"," place["country"]
  line = "Now:" sky(now["weather_code"])"," now["temperature_2m"] "°C, humidity",
         now["relative_humidity_2m"]"%, wind" now["wind_speed_10m"] "km/h"
  address dom
  'place: TEXT FROM title'
  'now: TEXT FROM line'
  'days: TABLE HEADER FROM rows'
  'note: TEXT "Data: Open-Meteo.com (CC BY 4.0)"'
  'show: ENABLE'
  say title"." line
  return

trouble: procedure
  use arg why
  msg = "Sorry:" why
  address dom
  'note: TEXT FROM msg'
  'show: ENABLE'
  return

-- WMO weather codes, as Open-Meteo documents them
sky: procedure
  parse arg code
  select
    when code = 0 then return "clear sky"
    when code <= 2 then return "partly cloudy"
    when code = 3 then return "overcast"
    when code <= 48 then return "fog"
    when code <= 57 then return "drizzle"
    when code <= 67 then return "rain"
    when code <= 77 then return "snow"
    when code <= 82 then return "rain showers"
    when code <= 86 then return "snow showers"
    otherwise return "thunderstorm"
  end

-- percent-encoding for a URL query (the string's bytes are UTF-8)
encode: procedure
  parse arg s
  out = ""
  do i = 1 to s~length
    c = s~subchar(i)
    if c~verify("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~") = 0
      then out ||= c
      else out ||= "%"c~c2x
  end
  return out

::requires "dom.cls"
::requires "fetch.cls"
