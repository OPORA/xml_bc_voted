require 'open-uri'
require 'json'
class GetMp
  def initialize
    @data_hash = JSON.load(open('http://bcmp.oporaua.org/'))
  end
  def serch_mp(full_name)
     #p full_name
   if full_name == "Підпалий Сергій Миколайович"
     return 6043
   elsif  full_name == "Дикий Геннадій Анатолійович"
     return 6044
   elsif  full_name == "Олійник Таісія Іванівна"
     return 6045
   else
     data = @data_hash.find {|k| k["full_name"] == full_name  }
     return data["deputy_id"]
   end
  end
end
