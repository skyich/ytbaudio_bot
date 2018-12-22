require 'telegram/bot'
require 'open-uri'

TOKEN = '752419982:AAHdSAz39JYbXJPmHokRy_lNr2TXeAODQRY'

loop do
  begin
    Telegram::Bot::Client.run(TOKEN, logger: Logger.new($stderr)) do |bot|
      bot.listen do |rqst|
        Thread.start(rqst) do |rqst|
          case rqst.text
          when '/start'
            bot.api.send_message(
              chat_id: rqst.chat.id,
              text: "Здравствуй, #{rqst.from.first_name}"
            )
          else
            begin
              link_reg = /v=(.*)/
              l = rqst.text.match(link_reg).captures
              l = l[0].strip
              uri = "https://www.easy-youtube-mp3.com/download.php?v=" + l
              puts uri
              source = open(uri, &:read)
              bot.api.send_message(
                chat_id: rqst.chat.id,
                text: 'Подготовка аудио-файла...'
              )
              reg = /<a class="btn btn-lg btn-success" href="([^"]*)"/
              link = source.match(reg).captures
              link  = link[0].strip
              bot.api.send_audio(chat_id: rqst.chat.id, audio: link)
            rescue
              bot.api.send_message(
                chat_id: rqst.chat.id,
                text: 'Неверная ссылка'
              )
            end
          end
        end
      end
    end
  rescue
    puts 'Что-то пошло не так'
  end
end
