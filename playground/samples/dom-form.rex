/* A form with ADDRESS DOM: fields, a check box, a button; the program      */
/* checks what was typed and answers in the same window.  FIELD makes a     */
/* labelled input; "name: VALUE INTO v" reads it; a label before a command  */
/* (name:) says which element, without moving the current one.             */
address dom
'NEW "Sign up"'
'CREATE - h3 "Rexx Symposium, sign-up"'
'FIELD name "Your name"'
'FIELD email "E-mail" EMAIL'
'FIELD year "Year you met Rexx" NUMBER'
'FIELD lunch "I will stay for lunch" CHECKBOX'
'BUTTON send "Sign up" SEND'
'CREATE msg p'
'CREATE summary div'
'name: FOCUS'

do forever
  'WAIT INTO ev'
  if ev~name = "CLOSE" then leave
  -- SEND: look at the fields
  'name: VALUE INTO name'
  'email: VALUE INTO email'
  'year: VALUE INTO year'
  'lunch: VALUE INTO lunch'
  select
    when name~strip == "" then call complain "Please tell us your name.", "name"
    when email~pos("@") = 0 then call complain "That e-mail does not look right.", "email"
    when \year~dataType("W") then call complain "The year, please (e.g. 1987).", "year"
    when year < 1979 | year > date("S")~left(4) then call complain "Rexx was born in 1979...", "year"
    otherwise do
      years = date("S")~left(4) - year
      text = "Thank you," name~strip"! Rexx and you:" years "years."
      'msg: TEXT FROM text'
      'msg: STYLE color ""'
      rows = .array~of(.array~of("Name", name~strip), .array~of("E-mail", email),,
                       .array~of("Lunch", word("no yes", lunch + 1)))
      'summary: CLEAR'
      'summary: TABLE FROM rows'
      say "Signed up:" name~strip "<"email">"
    end
  end
end
say "Bye."
exit

complain: procedure
  use arg text, field
  address dom
  'msg: TEXT FROM text'
  'msg: STYLE color #c62828'
  field': FOCUS'
  return

::requires "dom.cls"
