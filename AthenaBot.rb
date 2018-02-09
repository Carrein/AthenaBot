require "telegram/bot"
require "mongo"
require "json"

$token = "493714575:AAH7msrmnOScczmN0zi6aRH6MQCVu2rggqE"
$ip_addr = "127.0.0.1:27017"
$error_message = <<~HEREDOC
              Sorry, Athena does not recognize that format.
              To build a new scoreboard: 
              /new [BOARD_NAME] [HOUSE_NAME_1] [HOUSE_NAME_2] .. [NO_OF_OGs]
              i.e. /create AVENGERS THOR HULK IRON 3.
              HEREDOC
$delete_message = <<~HEREDOC
              WARNING! ATHENA CANNOT RECOVER DELETED SCOREBOARDS.

              TO CONFIRM DELETION, 
              PLEASE ENTER THE NAME OF THE SCOREBOARD IN THIS FORMAT IN CAPS:

              /DELETE [BOARD_NAME]
              HEREDOC
class String
  def numeric?
    Float(self) != nil rescue false
  end
end

#Pretty prints any given doc.
def pretty_print(args)
  return JSON.pretty_generate(args).delete('[]{},"').gsub(/\n\s*\n/, "\n")
end

#Print or edit a Bot message.
def print(new_message, new_text, new_markup = nil, edit_flag = false)
  Telegram::Bot::Client.run($token) do |bot|
    if edit_flag
      bot.api.edit_message_text(
      chat_id: new_message.from.id,
      message_id: new_message.message.message_id,
      text: new_text,
      reply_markup: new_markup
      )
    else
      bot.api.send_message(
      chat_id: new_message.from.id,
      text: new_text,
      reply_markup: new_markup
      )
    end
  end
end

#Checks if given arguments are valid to create a board.
def check(args)
  # 1. Checks if length of message is below 4.
  # 2. Checks if given OG number is numeric.
  # 3. Checks if given OG number is above 0.
  args.length <= 4 || !args[-1].numeric? || args[-1].to_i <= 0 ? false : true
end

#Generates a new board given a set of argument.
def new_board(args, identity)
  #Open connection to database.
  client = Mongo::Client.new([$ip_addr], :database => "camp")

  #Check if document exists.
  if client[:doc].find({"name": args[1].upcase}).count() > 0
    "Sorry, this scoreboard name exists. Please try again." 
  else
    #Create document.
    doc = {
      :name => args[1].upcase,
      :admins => [identity.from.id]
    }
    log = {
      :name => args[1].upcase,
      :log => ["#{args[1]} initalized by #{identity.from.first_name}."]
    }

    #Populate document with fields.
    group = {}
    args[-1].to_i.times do |i|
      group["OG #{i + 1}".to_sym] = 0;
    end
    (args.length - 3).times do |i|
      group["HOUSE".to_sym] = 0;
      doc[args[i+2].upcase.to_sym] = group
    end

    #Close connection and print scoreboard.
    client[:doc].insert_one(doc)
    client[:log].insert_one(log)
    client.close
    "Success!\nBoard details as follows:\n #{pretty_print(doc)}"
  end
end

#Print out all tasks available.
def tasks(var)
  kb = [
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "Add Points." , callback_data: "p_#{var}"),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "View Scores." , callback_data: "s_#{var}"),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "View Logs." , callback_data: "l_#{var}"),    
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "Add an Admin." , callback_data: "a_#{var}"),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "Remove an Admin." , callback_data: "r_#{var}"),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "Delete Scoreboard." , callback_data: "d_#{var}")
  ]
  Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
end

#Print out all collection available under this identity.
def collections(identity)
  client = Mongo::Client.new([$ip_addr], :database => "camp")
  kb = []
  client[:doc].find({"admins": identity.from.id}, projection: {"_id": 0, "name": 1}).each do |doc|
      kb << Telegram::Bot::Types::InlineKeyboardButton.new(text: doc.values.first , callback_data: "c_#{doc.values.first}")
  end
  client.close
  Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
end

#View scores/logs for any given collection.
def view(args)
  client = Mongo::Client.new([$ip_addr], :database => "camp")
  var = args[2..-1]
  t_doc = ""

  if args[0] == "l"
    client[:log].find({"name": var},
    projection: {"_id": 0}).each do |doc|
      t_doc = doc
    end
  end
  
  if args[0] == "s"
    client[:doc].find({"name": var},
    projection: {"_id": 0}).each do |doc|
      t_doc = doc
    end
  end
  client.close
  pretty_print(t_doc)
end

#Deletes a single document in a collection.
def delete(args)
  client = Mongo::Client.new([$ip_addr], :database => "camp")
  result = client[:doc].delete_one({"name": args})
  result = client[:log].delete_one({"name": args})
  client.close  
  return result.deleted_count
end

#Add/remove an admin from a dcoument.
def admin(identity, args, contact)
  client = Mongo::Client.new([$ip_addr], :database => "camp")
  var = args[2..-1]

  result = ""

  if args[0] == "a"
    if client[:doc].find({"name": var, "admins": contact.user_id}).count > 0
      result = "User already exists. Please try again."
    else
      client[:doc].update_one({"name": var }, {"$push" => {"admins" => contact.user_id}})
      client[:log].update_one({"name": var }, {"$push" => {"log" => "#{identity.from.first_name} added #{contact.first_name}."}})
      result = "Athena puts the new administrator in charge. Good luck."
    end
  else
    if client[:doc].find({"name": var, "admins": contact.user_id}).count > 0
      client[:doc].update_one({"name": var }, {"$pull" => {"admins" => contact.user_id}})
      client[:log].update_one({"name": var }, {"$push" => {"log" => "#{identity.from.first_name} removed #{contact.first_name}."}})
      result = "Athena drags the helpless administrator away. Goodbye."
    else
      result = "User does not exist. Please try again."
    end
  end
  client.close
  return result
end

def house(args)
  client = Mongo::Client.new([$ip_addr], :database => "camp")
  kb = []
  client[:doc].find({"name": args}, projection: {"_id": 0}).each do |doc|
    house = doc.keys[2..-1]
    house.each do |i|
      doc[i].keys.each do |o|
        value = "o_#{i}_#{o}_#{args}"
        kb << Telegram::Bot::Types::InlineKeyboardButton.new(text: "#{i} [#{o}].", callback_data: value)
      end
    end
  end
  client.close
  Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
end

def points(args)
  kb = [
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "+30" , callback_data: "30_#{args}"),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "+20" , callback_data: "20_#{args}"),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "+10" , callback_data: "10_#{args}"),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "-10" , callback_data: "-10_#{args}"),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "-20" , callback_data: "-20_#{args}"),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "-30" , callback_data: "-30_#{args}")
  ]
  Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
end

#Add points TODO.
def add(identity, args)
  loc = "#{args[1]}.#{args[2]}"
  client = Mongo::Client.new([$ip_addr], :database => "camp")
  client[:doc].update_one({"name": args[3]}, {"$inc" => {loc => args[0].to_i}})
  client[:log].update_one({"name": args[3] }, {"$push" => 
    {"log" => "#{identity.from.first_name} added #{args[0]} points to #{args[1]}, #{args[2]}."}
    })
  client.close
end

Telegram::Bot::Client.run($token) do |bot|
  bot.listen do |m|
  case m
    when Telegram::Bot::Types::CallbackQuery
      case m.data
      when /^[-\d].*/
        #Split TODO.
        var = m.data.split("_")
        add(m, var)
        print(m, "Points added! Updated scoreboard: ", nil, true)
        #Padded variable TODO.
        print(m, view("s_#{var[3]}"))
      when /^c.*/
        #Truncate identifier.
        var = m.data[2..-1]
        print(m, "Okay, what would you like to do?", tasks(var), true)
      when /^o.*/
        var = m.data[2..-1]
        print(m, "How many points to add?", points(var), true)
      when /^p.*/
        var = m.data[2..-1]
        print(m, "Pick an OG or a house.", house(var), true)
      when /^[sl].*/
        print(m, view(m.data), nil, true)
      when /^[ar].*/
        print(m, "Okay, forward the contact you would like to remove/add to Athena.", nil, true)
        bot.listen do |n|
          if n.contact
            if !n.contact.user_id.nil?
              print(m, admin(m, m.data, n.contact))
            else
              print(m, "Sorry, please ensure the contact has Telegram and a country code (+65) added.")
            end
          else
            print(m, "Athena does not recognize that command. Say what?")
          end
          break;
        end
      when /^d.*/
        var = m.data[2..-1]
        print(m, $delete_message)
        bot.listen do |n|
          if n.text == "/DELETE #{var}"
            print(m, "No. of document deleted: #{delete(var)}")
            break
          else 
            print(m, "Name entered incorrectly, board is unmodified.")
            break
          end
        end
      else
        print(m, "Something in Athena just froze! Please contact the administrator.", nil, true)
      end
    when Telegram::Bot::Types::Message
      case m.text
      when /^\/edit/
        #Shows all available collections associated with this account.
        print(m, "Pick a scoreboard for Athena to edit.", collections(m))
      when /^\/new.*/
        new_message = m.text.split
        #Splits message text for checking.
        if check(new_message)
          print(m, "Okay, Athena is searching for an empty scoreboard...")
          print(m, new_board(new_message, m))
        else
          print(m, $error_message)
        end
      when '/new'
        print(m, "new")
      else
        print(m, "Athena does not recognize that command. Say what?")
      end
    end
  end
end