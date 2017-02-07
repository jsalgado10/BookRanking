# BookRanking
A Book Ranking application that will sent a https request and parse the response to extract the rank and title of the book

The application was done using Ruby, an imperative language, and Elixir,a purely functional language.

It focuses on the 3 different solutions
1. Using an iterator to send one request at the time
2. Sending all https requests using multiple threads
3. Sending all https request and prevent race conditions using locks
