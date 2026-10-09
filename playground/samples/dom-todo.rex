/* A to-do panel with ADDRESS DOM: build it, WAIT for something to happen,  */
/* look at what it was, act; as XEDIT's READ or ISPF's DISPLAY, no          */
/* callbacks.  Type an item and press Enter; click an item to cross it out  */
/* (again: back); "Clear done" removes the crossed-out ones.                */
address dom
'NEW "To do" AS todo'
'CSS ".done { text-decoration: line-through; opacity: .55; } li { cursor: pointer; }"'
'FIELD item'
'item: ATTR placeholder "Something to do, then Enter"'
'item: ON enter ADD'
'CREATE items ul'
'CREATE bar div'
'bar: CLASS row'
'bar: BUTTON clear "Clear done" CLEAR'
'bar: CREATE count span'
'item: FOCUS'
n = 0                                   -- items made so far
done. = 0                               -- done.k: item k is crossed out
gone. = 0                               -- gone.k: item k was cleared
call count

do forever
  'WAIT INTO ev'
  select
    when ev~name = "ADD" then do
      'item: VALUE INTO text'
      if text~strip == "" then iterate
      n += 1
      'items: CREATE item'n 'li FROM text'
      'item'n': ON click TOGGLE'
      'item: VALUE ""'
    end
    when ev~name = "TOGGLE" then do      -- ev~target: the item's nickname
      k = ev~target~substr(5)
      done.k = \done.k
      if done.k then ev~target': CLASS +done'
      else ev~target': CLASS -done'
    end
    when ev~name = "CLEAR" then do k = 1 to n
      if done.k then do
        'item'k': REMOVE'
        done.k = 0; gone.k = 1
      end
    end
    when ev~name = "CLOSE" then leave
  end
  call count
end
say "Bye."
exit

count: procedure expose n done. gone.
  left = 0
  do k = 1 to n
    if \done.k & \gone.k then left += 1
  end
  msg = left "to do"
  'count: TEXT FROM msg'
  return

::requires "dom.cls"
