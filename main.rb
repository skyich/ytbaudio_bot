require 'telegram/bot'
require 'open-uri'
require 'down'

TOKEN = 'YOUR BOT TOKEN'

#скачиваем и разделяем аудио на равные части по ~ 50 мб
def split_audio(uri, song_name, size)
  tempfile = Down.download(uri)
  system("ffmpeg -i #{tempfile.path} -f segment -segment_time 1200 -c copy #{song_name}_part%d.mp3")
  name = Dir["#{song_name}*"]
  return name
end

# формируем ссылку для запроса
def make_link(message)
  link_reg = /v=(.*)/
  l = message.text.match(link_reg).captures
  return "https://www.easy-youtube-mp3.com/download.php?v=" + l[0].strip
end

# получаем всю информацию для загрузки аудио
def get_download_info(uri)
  source = open(uri, &:read)
  reg_link = /<a class="btn btn-lg btn-success" href="([^"]*)"/
  link = source.match(reg_link).captures
  link  = link[0].strip
  reg_size = /kbps - ([^\s]*)/
  size = source.match(reg_size).captures
  size = size[0].to_f
  reg_song_name = /<title>(.*) - Easy/
  song_name = source.match(reg_song_name).captures
  song_name = song_name[0].downcase.gsub(/[^a-zа-я0-9\s]/i, '').strip
  song_name.gsub!(/\s/,'_')
  return link, size, song_name
end

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
              bot.api.send_message(
                chat_id: rqst.chat.id,
                text: 'Подготовка аудио...'
              )
              link, size, song_name = get_download_info(make_link(rqst))
              if size <= 19
                bot.api.send_audio(chat_id: rqst.chat.id, audio: link)
              elsif size > 19 && size < 200
                name = split_audio(link, song_name, size)
                name.each do |song|
                  puts song
                  bot.api.send_audio(chat_id: rqst.chat.id, audio: Faraday::UploadIO.new("#{song}", 'music/mp3'))
                  File.delete(song)
                end
              else
                bot.api.send_message(
                  chat_id: rqst.chat.id,
                  text: 'Слишком большой файл для загрузки'
                )
              end
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
