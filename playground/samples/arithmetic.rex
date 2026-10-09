/* Rexx arithmetic is decimal, with as many digits as you ask for        */
say "1/3 with 9 digits:  " 1/3
numeric digits 80
say "1/3 with 80 digits: " 1/3
say "2**200 =" 2**200
say "50! =" factorial(50)
say "0.1 + 0.2 =" 0.1 + 0.2 "(exactly)"
numeric digits 1000
pi = pi(1000)
say "pi to 100 places:" left(pi, 102)
exit

factorial: procedure
  arg n
  if n <= 1 then return 1
  return n * factorial(n - 1)

pi: procedure   /* Machin's formula, 4*(4*atan(1/5) - atan(1/239)) */
  numeric digits arg(1) + 5
  return format(4 * (4 * arctan(5) - arctan(239)), , arg(1))

arctan: procedure   /* arctan(1/x) */
  arg x
  sum = 0; term = 1 / x; k = 1; sign = 1; x2 = x * x
  do forever                  /* until the terms no longer change the sum */
    old = sum
    sum = sum + sign * term / k
    if sum = old then return sum
    term = term / x2; k = k + 2; sign = -sign
  end
