def fib(n)
    a, b = 0, 1
    n.times { a, b = b, a + b }
    a
end

# p fib(300000)