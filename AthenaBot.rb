require "telegram/bot"
require "mongo"
require "json"

token = "523662364:AAHcT20O_ztg9My1AGyOuOiprMuWyAzXNXc"
$document = ""
$house = ""

def new_board(build_array, identity)
  ip_addr = "127.0.0.1:27017"
  client = Mongo::Client.new([ip_addr], :database => "camp")

  if (client[:inventory].find({"name": build_array[1]}).count() == 1)
    value = "Sorry, this document already exist. Please try again."
  else
    document = {:name => build_array[1], :owner => [identity], :admins => [identity]}
    group = {}
      build_array[-1].to_i.times do |j|
        group["OG #{j + 1}".to_sym] = 0;
      end
      (build_array.length - 3).times do |i|
        document[build_array[i+2].to_sym] = group
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

def show_admin()
  value = ""
  ip_addr = "127.0.0.1:27017"
  client = Mongo::Client.new([ip_addr], :database => "camp")
  client[:inventory].find({}, projection: {"_id": 0, "owner": 1, "admins": 1}).each do |doc|
    value = JSON.pretty_generate(doc).delete('{},"').gsub(/\n\s*\n/, "\n")
  end
  client.close
  return value
end

def show_board(doc)
  doc = doc[2..-1]
  value = ""
  ip_addr = "127.0.0.1:27017"
  client = Mongo::Client.new([ip_addr], :database => "camp")
  client[:inventory].find({"name": doc}, projection: {"_id": 0, "owner": 0, "admins": 0}).each do |doc|
    value = JSON.pretty_generate(doc).delete('{},"').gsub(/\n\s*\n/, "\n")
  end
  client.close
  return value
end

def collections_keyboard(identity, value)
  ip_addr = "127.0.0.1:27017"
  client = Mongo::Client.new([ip_addr], :database => "camp")
  kb = []

  if value == "u"
    client[:inventory].find({"owner": identity}, projection: {"_id": 0, "name": 1}).each do |doc|
      value = "h_" + doc.values.first
      kb << Telegram::Bot::Types::InlineKeyboardButton.new(text: doc.values.first , callback_data: value)
    end
  elsif value == "g"
    client[:inventory].find({"admins": identity}, projection: {"_id": 0, "name": 1}).each do |doc|
      value = "g_" + doc.values.first
      kb << Telegram::Bot::Types::InlineKeyboardButton.new(text: doc.values.first , callback_data: value)
    end
  else
    client[:inventory].find({}, projection: {"_id": 0, "name": 1}).each do |doc|
      value = "v_" + doc.values.first
      kb << Telegram::Bot::Types::InlineKeyboardButton.new(text: doc.values.first.to_s , callback_data: value)
    end
  end
  client.close
  markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
end

def show_houses(doc)
  doc = doc[2..-1]
  ip_addr = "127.0.0.1:27017"
  client = Mongo::Client.new([ip_addr], :database => "camp")
  kb = []
  v = []
  $document = doc
  client[:inventory].find({"name": doc}, projection: {"_id": 0}).each do |doc|
    v = doc.keys[3..-1]
  end
  v.each do |i|
    value = "o_" + i
    kb << Telegram::Bot::Types::InlineKeyboardButton.new(text: i , callback_data: value)
  end
  client.close
  markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
end

def show_og(doc)
  doc = doc[2..-1]
  $house = doc
  ip_addr = "127.0.0.1:27017"
  client = Mongo::Client.new([ip_addr], :database => "camp")
  kb = []
  client[:inventory].find({"name": $document}, projection: {"_id": 0, doc => 1}).each do |e|
    e[doc].keys.each do |j|
    value = "p_" + j
    kb << Telegram::Bot::Types::InlineKeyboardButton.new(text: j, callback_data: value)
    end
  end
  client.close
  markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
end


def tasks_keyboard(doc)
  doc = doc[2..-1]
  kb = [
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "Delete Scoreboard." , callback_data: "d_" + doc),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "Add new Admin." , callback_data: "a_" + doc),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "Remove an Admin." , callback_data: "r_" + doc)
    # Telegram::Bot::Types::InlineKeyboardButton.new(text: "" , callback_data: )
    # Telegram::Bot::Types::InlineKeyboardButton.new(text: "-20" , callback_data: )
    # Telegram::Bot::Types::InlineKeyboardButton.new(text: "-30" , callback_data: )
  ]
  markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
end

def delete_doc(doc)
  doc = doc[2..-1]
  ip_addr = "127.0.0.1:27017"
  client = Mongo::Client.new([ip_addr], :database => "camp")
  result = client[:inventory].delete_one({"name": doc})
  client.close  
  return result.deleted_count
end

def modify_admin(identity, doc)
  ip_addr = "127.0.0.1:27017"
  client = Mongo::Client.new([ip_addr], :database => "camp")
  puts doc
  if doc[0] == 'a'
    doc = doc[2..-1] 
    client[:inventory].update_one({"name": doc}, {"$push" => {"admins" => identity}})
  else
    doc = doc[2..-1]
    client[:inventory].update_one({"name": doc}, {"$pull" => {"admins" => identity}})
  end
  client.close
end

def add_scores(doc)
  puts doc
  ip_addr = "127.0.0.1:27017"
  client = Mongo::Client.new([ip_addr], :database => "camp")
  if doc[0] == "-"
    value = doc[0..3].to_i
    puts value
    doc = doc[4..-1]
    puts doc
    loc = $house + "." + doc
    client[:inventory].update_one({"name": $document}, {"$inc" => {loc => value}})
  else
    value = doc[0..2].to_i
    puts value
    doc = doc[3..-1]
    puts doc
    loc = $house + "." + doc

    client[:inventory].update_one({"name": $document}, {"$inc" => {loc => value}})       
  end
  client.close
end

def points_keyboard(doc)
  doc = doc[2..-1]
  kb = [
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "+30" , callback_data: "30_" + doc),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "+20" , callback_data: "20_" + doc),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "+10" , callback_data: "10_" + doc),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "-10" , callback_data: "-10_" + doc),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "-20" , callback_data: "-20_" + doc),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "-30" , callback_data: "-30_" + doc)
  ]
  markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
  return markup
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
      case message.data
      when /^.?\d{2}/
        add_scores(message.data)
        bot.api.send_message(chat_id: message.from.id, text: "Points added!")
      when /^p_(.*)/
        bot.api.send_message(chat_id: message.from.id, text: "How many points?", reply_markup: points_keyboard(message.data))
      when /^g_(.*)/
        bot.api.send_message(chat_id: message.from.id, text: "Pick a house.", reply_markup: show_houses(message.data))
      when /^o_(.*)/
        bot.api.send_message(chat_id: message.from.id, text: "Pick an OG.", reply_markup: show_og(message.data))        
      when /^v_(.*)/
        bot.api.send_message(chat_id: message.from.id, text: show_board(message.data));
      when /^h_(.*)/
        bot.api.send_message(chat_id: message.from.id, text: "OK what would you like to do with this group?", reply_markup: tasks_keyboard(message.data))
      when /^d_(.*)/
        bot.api.send_message(chat_id: message.from.id, text: "Number of documents deleted: " + delete_doc(message.data).to_s)       
      when /^a_(.*)/
        bot.api.send_message(chat_id: message.from.id, text: "Forward the contact which you would like to add as admin.")
        bot.listen do |n|
          if !n.contact.user_id.nil?
            modify_admin(n.contact.user_id, message.data)
            bot.api.send_message(chat_id: message.from.id, text: "Administrator added. Updated Scoreboard: " + show_admin())
            break
          else
            bot.api.send_message(chat_id: message.from.id, text: "Sorry, either the contact does not have Telegram or that is an invalid input.")
          end
        end
      when /^r_(.*)/
        bot.api.send_message(chat_id: message.from.id, text: "Forward the contact which you would like to remove as admin.")
        bot.listen do |n|
          if !n.contact.user_id.nil?
            modify_admin(n.contact.user_id, message.data)            
            bot.api.send_message(chat_id: message.from.id, text: "Administrator removed. Updated Scoreboard: " + show_admin())
            break
          else
            bot.api.send_message(chat_id: message.from.id, text: "Forward the contact which you would like to remove as admin.")           
          end
        end
      end
    when Telegram::Bot::Types::Message
      case message.text
      when '/add'
        bot.api.send_message(chat_id: message.chat.id, text: 'Pick a scoreboard to update.', reply_markup: collections_keyboard(message.from.id, "g"))
      when '/view'
        bot.api.send_message(chat_id: message.chat.id, text: 'Pick a scoreboard to view.', reply_markup: collections_keyboard(message.from.id, "v"))
      when '/update'
        bot.api.send_message(chat_id: message.chat.id, text: 'Pick a scoreboard to edit.', reply_markup: collections_keyboard(message.from.id, "u"))
      when /^\/create(.*)/
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