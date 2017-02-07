defmodule Books do

  defstruct [:isbn, :title, :rank]

  def print_list(list) do
    IO.puts "#{String.ljust("Book Title",60)}#{String.ljust("ISBN",15)}#{String.ljust("Rank",10)}"
    IO.puts "#{String.ljust("",85,?-)}"
    Enum.each(list,fn(book)-> IO.puts "#{String.ljust(book.title,60)}#{String.ljust(book.isbn,15)}#{String.ljust(Integer.to_string(book.rank),10)}" end)
  end

  def read_file(source) do
    File.read!(source)
  end

  def split_isbn(file_content) do
    String.split(file_content,"\r\n", trim: true)
  end

  def get_title(html_content) do
    Regex.scan(~r/<span id="productTitle" class=".*?">(.*?)<\/span>/,html_content, capture: :all_but_first) |> to_string
  end

  def get_rank(html_content) do
    Regex.scan(~r/<li id="SalesRank"> <b>Amazon Best Sellers Rank:<\/b>(.*?) in.*?/,html_content, capture: :all_but_first) |> to_string |>String.replace(["#",","," "],"") |> String.to_integer
  end

  def get_html_response(isbn) do
    uri = 'https://www.amazon.com/exec/obidos/ASIN/#{isbn}'
    :inets.start()
    :ssl.start()
    {:ok, { _, _, body}} = :httpc.request(:get, {uri,[]}, [], [])
    body |> to_string
         |> String.replace("\n"," ")
  end

  def run_process(content, func, msg) do
    IO.puts msg
    start = DateTime.utc_now() |> DateTime.to_unix()
    isbns = split_isbn(content)
    list = func.(isbns)
    stop = DateTime.utc_now() |> DateTime.to_unix()
    print_list(list)
    IO.puts "\nRequest completed in #{stop - start} seconds\n"
  end

  def get_data_for_a_book(isbn) do
    html_code = get_html_response(isbn)
    title = get_title(html_code)
    rank = get_rank(html_code)
    %Books{isbn: isbn , title: title, rank: rank}
  end

  def get_books_data_sequential(books_isbns) do
    Enum.map(books_isbns, fn(isbn) -> get_data_for_a_book(isbn) end) |> Enum.sort_by(&(&1.rank))
  end

  def get_books_data_concurrent(books_isbns) do
    parent = self
    pids = Enum.map(books_isbns, fn(isbn)->
      spawn_link(fn() ->
        result = get_data_for_a_book(isbn)
        send(parent, {:ok, result}) end)
    end)
    Enum.map(pids, fn(_) ->
      receive do
        {:ok, result} -> result
      end
    end) |> Enum.sort_by(&(&1.rank))
  end

  def sequential_run(content) do
    run_process content, fn(isbns) -> get_books_data_sequential(isbns) end, "[Running Sequential Process]"
  end

  def concurrent_run(content) do
    run_process content, fn(isbns) -> get_books_data_concurrent(isbns) end, "[Running Concurrent Process]"
  end
end

filename = String.split(hd(System.argv), ":", parts: 1) |> to_string |> String.replace("\r","")
content = Books.read_file(filename)
Books.sequential_run(content)
Books.concurrent_run(content)
