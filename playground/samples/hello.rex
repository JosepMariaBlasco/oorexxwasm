/* Standard input is interactive: type into the console and press Enter.  */
/* An empty line ends the program; so does Ctrl+D (end of file).          */
say "What's your name?"
do forever
  call charout , "> "
  parse pull name
  if name = "" then leave
  say "Hello," name"! Your name has" length(name) "characters,",
      "and backwards it reads" reverse(name)"."
  say "Another name? (empty line to stop)"
end
say "Bye."
