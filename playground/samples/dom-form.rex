/* A form with ADDRESS DOM: fields, a check box, a button; the program      */
/* checks what was typed and answers in the same window.  FIELD makes a     */
/* labelled input; name VALUE INTO 'who' reads it: a target before the      */
/* command says which element, without moving the current one.  Commands    */
/* need no quotes; quoted is what Rexx must not touch: values with blanks   */
/* or lower case, the names of variables (after INTO and FROM), and words   */
/* that are also variables (so no variable here is called text or value).   */
address dom
NEW '"Sign up"'
CREATE '- h3 "Rexx Symposium, sign-up"'
FIELD name '"Your name"'
FIELD email '"E-mail"' EMAIL
FIELD year '"Year you met Rexx"' NUMBER
FIELD lunch '"I will stay for lunch"' CHECKBOX
BUTTON send '"Sign up"' SEND
CREATE msg p
CREATE summary div
name FOCUS

do forever
  WAIT INTO 'ev'
  if ev~name = "CLOSE" then leave
  -- SEND: look at the fields
  name VALUE INTO 'who'
  email VALUE INTO 'mail'
  year VALUE INTO 'met'
  lunch VALUE INTO 'stay'
  select
    when who~strip == "" then call complain "Please tell us your name.", "name"
    when mail~pos("@") = 0 then call complain "That e-mail does not look right.", "email"
    when \met~dataType("W") then call complain "The year, please (e.g. 1987).", "year"
    when met < 1979 | met > date("S")~left(4) then call complain "Rexx was born in 1979...", "year"
    otherwise do
      years = date("S")~left(4) - met
      thanks = "Thank you," who~strip"! Rexx and you:" years "years."
      msg TEXT FROM 'thanks'
      msg STYLE color '""'
      rows = .array~of(.array~of("Name", who~strip), .array~of("E-mail", mail),,
                       .array~of("Lunch", word("no yes", stay + 1)))
      summary CLEAR
      summary TABLE FROM 'rows'
      say "Signed up:" who~strip "<"mail">"
    end
  end
end
say "Bye."
exit

-- which: the nickname of the field to go back to (a variable, on purpose)
complain: procedure
  use arg why, which
  address dom
  msg TEXT FROM 'why'
  msg STYLE color '#c62828'
  which FOCUS
  return

::requires "dom.cls"
