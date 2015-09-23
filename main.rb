require 'nokogiri'
require 'capybara'
require 'capybara/poltergeist'
require 'csv'

def get_asins_from_file(file_name)
  begin
    parsed_file = CSV.read(file_name, { :col_sep => "\t" })
  rescue CSV::MalformedCSVError
    puts "failed to parse file: #{file_name}"
    return []
  end

  asins = []
  parsed_file.each do |line|
    if line[2] != "asin" then asins << line[2] end
  end
  return asins
end

def get_seller_name(row)
  row.css('.olpSellerName').each do |seller|
    seller.children.each do |child|
      # not amazon & img
      return child.attribute('href') if child.attribute('href') != nil
      # amazon
      return child.attribute('src')  if child.attribute('src') != nil
      child.children.each do |child2| 
        # not amazon & string
        return child2.attribute('href') if child2.attribute('href') != nil
      end
    end
  end
end

def seller_is_FBA(row)
  row.css('.olpBadge').each do |badge|
    return true
  end
  return false
end

def get_next_url(page)
  page.css('.a-last').each do |next_button|
    next_button.children.each do |child|
      url = child.attribute('href')
      if url == nil then return '' else return url.value end
    end
  end
end

def get_num_of_FBA(session, a_sin)
  fba_count   = 0
  prefix      = 'http://www.amazon.com/'
  url         = prefix + 'gp/offer-listing/' + a_sin
  while (true) do
    session.visit(url)
    if session.status_code == 404 then 
      p '404Err:' + url + ' ASIN:' + a_sin 
      return fba_count
    else 
      p "#{session.status_code}:#{url} ASIN:#{a_sin}"
    end
    page = Nokogiri::HTML.parse(session.html)
    page.css('.olpOffer').each do |seller|
      if seller_is_FBA(seller)
        #p get_seller_name(seller) 
        fba_count += 1
      end
    end
    next_url = get_next_url(page)
    if next_url.class != String then return fba_count end
    if next_url != '' then url = prefix + next_url else return fba_count end
  end
  return fba_count
end

if __FILE__ == $0
  Capybara.run_server = false
  Capybara.register_driver :poltergeist do |app|
    Capybara::Poltergeist::Driver.new(app)
  end
  session = Capybara::Session.new(:poltergeist)
  session.driver.headers = { 'User-Agent' => "Mozilla/5.0 (Macintosh; Intel Mac OS X)" } 
  file_name = 'num_of_FBA_seller.txt'
  if File.exist?(file_name) then File.delete(file_name) end
  if ARGV[0] == nil
    p "Please input file name as Args1.\nFile must be exported from Amazon Fulfilled Inventory."
    exit(-1)
  end
  p "Start:#{Time.now}"
  get_asins_from_file(ARGV[0]).each do |a_sin|
    count = get_num_of_FBA(session, a_sin)
    File.open(file_name, 'a') {|f| f.write("#{a_sin},#{count.to_s}\n")}
  end
  p "End:#{Time.now}"
end

