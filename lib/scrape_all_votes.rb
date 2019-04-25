require_relative 'voted'
require_relative 'get_mps'
require 'json'
require 'date'
require 'open-uri'
require 'csv'
require 'nokogiri'
class GetAllVotes
   def initialize
     @all_file = get_all_file()
     $all_mp =  GetMp.new
   end
   def get_all_file
     hash = []
     url = "http://195.22.141.33/xml/"
     page = Nokogiri::HTML(open(url, "User-Agent" => "HTTP_USER_AGENT:Mozilla/5.0 (Windows; U; Windows NT 6.0; en-US) AppleWebKit/534.13 (KHTML, like Gecko) Chrome/9.0.597.47"), nil, 'utf-8')
     page.css('table tr').each do |tr|
       next if tr.css('a').first.nil?
       next if tr.css('a').first.text == "Name"  or tr.css('a').first.text =="Parent Directory"
       hash << { path: tr.css('a')[0][:href], last_modified: tr.css('td')[2].text.strip }
     end
     return hash
   end
  def get_all_votes
    @all_file.each do |f|
      update = UpdatePar.first(url: f[:path], last_modified: f[:last_modified])
      if update.nil?
        read_file("http://195.22.141.33/xml/" + f[:path], f[:last_modified] )
        UpdatePar.create!(url: f[:path], last_modified: f[:last_modified])
      end
    end
  end
  def read_file(file, create)
    hash = []
    absents = []
    xml = Nokogiri::XML(open(file, "User-Agent" => "HTTP_USER_AGENT:Mozilla/5.0 (Windows; U; Windows NT 6.0; en-US) AppleWebKit/534.13 (KHTML, like Gecko) Chrome/9.0.597.47"), nil, 'cp1251')
    xml.xpath('//Deputats/*').each do |mp|
      if mp.at_xpath('Present').text == "Відсутній"
        absents << $all_mp.serch_mp(mp.at_xpath('FIO').text)
      end
    end

    xml.xpath('//Vopros').each do |v|
       division = {}
       division[:number] =  v.xpath('ID').text
       date_text =  v.xpath('Voted').text
       division[:date_caden] = DateTime.parse(date_text).strftime('%Y-%m-%d')
       division[:date_vote] = DateTime.parse(date_text).strftime('%Y-%m-%d %H:%M:%s')
       division[:name] = v.xpath('Long').text
       if v.xpath('Result').text == "РІШЕННЯ ПРИЙНЯТО"
         division[:result] = "Прийнято"
       else
         division[:result] = "Не прийнято"
       end
       division[:voted] = []
       v.xpath('Poimen/Deputat').each do |r|
         deputy = $all_mp.serch_mp(r.xpath('Name').text)
         if r.xpath('Golos').text == "Н/Г"
           if absents.include?(deputy)
             vote = "absent"
           else
             vote = "not_voted"
           end
         else
           vote = short_voted_result(r.xpath('Golos').text)
         end
         division[:voted] << { voter_id: deputy, result: vote }
       end
       hash << division
    end
    save_vote(hash)
  end
   def save_vote(hash)
     hash.each do |r|

       event = VoteEvent.first(name: r[:name], number: r[:number], date_caden: r[:date_caden], date_vote: r[:date_vote], rada_id: 8, option: r[:result])
          if event.nil?
            p "Create"
            division = VoteEvent.create!(name: r[:name], number: r[:number], date_caden:  r[:date_caden], date_vote: r[:date_vote], rada_id: 8, option: r[:result], date_created: Date.today)
            p division
          else
            p "update"
            division = event
            division.votes.destroy!
          end

       r[:voted].each do |v|
           vote = division.votes.new
           vote.voter_id = v[:voter_id]
           vote.result = v[:result]
           vote.save
       end
     end
   end
  def short_voted_result(result)
    hash = {
        "Н/Г":  "not_voted",
        Відсутній: "absent",
        Проти:  "against",
        За: "aye",
        "Утр.": "abstain",
    }
    hash[:"#{result.upcase}"]
  end
end
#GetAllVotes.new.get_all_votes()