require "telegram/bot"
require "mongo"
require "json"

token = "523662364:AAHcT20O_ztg9My1AGyOuOiprMuWyAzXNXc"


def new_board(build_array, identity)
  ip_addr = "127.0.0.1:27017"
  client = Mongo::Client.new([ip_addr], :database => "camp")

  if (client[:inventory].find({"name": build_array[1]}).count() == 1)
    value = "Sorry, this document already exist. Please try again."
  else
    document = {:name => build_array[1], :owner => identity, :admins => identity}
    group = {}
      build_array[-1].to_i.times do |j|
        group["Group #{j + 1}"] = 0;
      end
      (build_array.length - 3).times do |i|
        document[build_array[i+2]] = group
      end
    client[:inventory].insert_one(document)
      client[:inventory].find({}, projection: {"_id": 0, "owner": 0, "admins": 0}).each do |doc|
        value = JSON.pretty_generate(doc).delete('{},"').gsub(/\n\s*\n/, "\n")
      end
    value.prepend("Success! Scoreboard details:")
    client.close
  end
  return value;
end

def phone_number_keyboard()
  kb = [
    Telegram::Bot::Types::KeyboardButton.new(
      text: "Give me your phone number", 
      request_contact: true
      )
  ]
  return markup = Telegram::Bot::Types::ReplyKeyboardMarkup.new(
    keyboard: kb, 
    one_time_keyboard: true
    )
end

def collection_keyboard(identity)
  ip_addr = "127.0.0.1:27017"
  client = Mongo::Client.new([ip_addr], :database => "camp")
  kb = []
  client[:inventory].find({"owner": identity}, projection: {"_id": 0, "name": 1}).each do |doc|
    kb << Telegram::Bot::Types::InlineKeyboardButton.new(text: doc.values.first , callback_data: "house")
  end
  markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
  return markup
end

def points_keyboard()
  kb = [
    # Telegram::Bot::Types::InlineKeyboardButton.new(text: "+30" , callback_data: )
    # Telegram::Bot::Types::InlineKeyboardButton.new(text: "+20" , callback_data: )
    # Telegram::Bot::Types::InlineKeyboardButton.new(text: "+10" , callback_data: )
    # Telegram::Bot::Types::InlineKeyboardButton.new(text: "-10" , callback_data: )
    # Telegram::Bot::Types::InlineKeyboardButton.new(text: "-20" , callback_data: )
    # Telegram::Bot::Types::InlineKeyboardButton.new(text: "-30" , callback_data: )
  ]
  markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
  return markup
end

def add_user()

end

class String
  def numeric?
    Float(self) != nil rescue false
  end
end

Telegram::Bot::Client.run(token) do |bot|
  bot.listen do |message|
    case message
    when Telegram::Bot::Types::CallbackQuery
      if message.data == 'house'
        bot.api.send_message(chat_id: message.from.id, text: "Please forward the contact of the person you would like to make an admin.")  
        bot.listen do |message|
          case message
          when Telegram::Bot::Types::Message
          if !message.contact.user_id.nil?
            bot.api.send_message(chat_id: message.from.id, text: message.contact.user_id.to_s)
            break
          else
            bot.api.send_message(chat_id: message.chat.id, text: "Sorry, either the contact does not have Telegram or that is an invalid input.")
          end
        end
        end
      end
    when Telegram::Bot::Types::Message
      case message.text
      when 'access'
      when '/edit'
        bot.api.send_message(chat_id: message.chat.id, text: 'Pick a scoreboard to edit.', reply_markup: collection_keyboard(message.from.id))
      when /^\/build(.*)/
        build_array = message.text.split
        if build_array.length <= 3
          bot.api.send_message(chat_id: message.chat.id, text: "Please enter at least one house and one team and the scoreboard name." )
          elsif (!build_array[-1].numeric? || build_array[-1].to_i <= 0)
            bot.api.send_message(chat_id: message.chat.id, text: "The number of teams have to be numerical and not zero.")
              else
                bot.api.send_message(chat_id: message.chat.id, text: new_board(build_array, message.from.id))               
              end
      else
        bot.api.send_message(chat_id: message.chat.id, text: "Athena does not recognize that command. Say what?")
      end
    end
  end
end


