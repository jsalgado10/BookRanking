require "net/https"
require "rexml/document"
require "thread"
include REXML

Books = Struct.new(:isbn, :title, :rank )

def print_list(list)
	format = "%-60s%-15s%-10s\n"
	printf(format,"Book Title","ISBN","Rank")
	puts "-" * 85
	list.each {|book| printf(format,book.title,book.isbn,book.rank)}
end

def read_file(source)
	IO.readlines(source)
end

def split_isbn(file_content)
	file_content.map { |isbn| isbn.gsub(/[\n\r]/,"").to_s  }
end

def get_title(html_content)
	html_content.scan(/<span id="productTitle" class=".*?">(.*?)<\/span>/).last.first
end

def get_rank(html_content)
	html_content.scan(/<li id="SalesRank"> <b>Amazon Best Sellers Rank:<\/b>(.*?) in.*?/).last.first.gsub(/[#, ]/,"").to_i
end

def get_html_response(isbn)
	uri = URI.parse('https://www.amazon.com/exec/obidos/ASIN/'+ isbn)
	agent = 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/54.0.2840.71 Safari/537.36'
	html_content = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == "https", :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |https|
		httprequest = Net::HTTP::Get.new(uri.path,{'User-Agent' => agent})
		response = https.request(httprequest)
		response.body.gsub(/[\n]/," ")
	end
end

def run_process(filename)
	start = Time.now
	content = read_file(filename)
	isbns = split_isbn(content)
	list = yield isbns
	print_list(list)
	complete = Time.now
	puts "\nRequest completed in #{complete - start} seconds\n\n"
end

def get_data_for_a_book(isbn)
	html_code = get_html_response(isbn)
	title = get_title(html_code)
	rank = get_rank(html_code)
	Books.new(isbn,title,rank)
end

def get_books_data_sequential(books_isbns)
	books_isbns.map do |isbn|
		get_data_for_a_book(isbn)
	end.sort_by(&:rank)
end

def get_books_data_concurrent(books_isbns)
	list = []
  mutex = Mutex.new
  threads = books_isbns.map do |isbn|
    Thread.new(isbn) do |isbn|
			result = get_data_for_a_book(isbn)
      mutex.synchronize do
				list << result
      end
    end
  end
    threads.each do |t|
    	t.join
    end
    list.sort_by(&:rank)
end

def get_books_data_fork(books_isbns)
	pids = books_isbns.map do |isbn|
		reader, writer = IO.pipe
		fork do
			reader.close
			result = get_data_for_a_book(isbn)
			Marshal.dump(result, writer)
		end
		writer.close
		reader
	end
	Process.waitall
	pids.map { |pipe| Marshal.load(pipe.read)}.sort_by(&:rank)
end

def sequential_run(filename)
	puts "[Running Sequential Process]"
	run_process(filename) { |isbns| get_books_data_sequential(isbns)}
end

def concurrent_run(filename)
	puts "[Running Concurrent Process]"
	run_process(filename) { |isbns| get_books_data_concurrent(isbns)}
end

def fork_run(filename)
	puts "[Running Fork Process]"
	run_process(filename) { |isbns| get_books_data_fork(isbns)}
end

filename = ARGV[0].to_s
sequential_run(filename)
concurrent_run(filename)
fork_run(filename)
