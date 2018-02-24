require "telegram/bot"
require "mongo"
require "json"

$token = open("lib/assets/.auth_token").read().to_s
$ip_addr = open("lib/assets/.ip_addr").read().to_s

$error_message = <<~HEREDOC
              *Sorry, Athena does not recognize that format.

              To build a new scoreboard:*

              `/new [BOARD_NAME] [HOUSE_NAME_1] [HOUSE_NAME_2] .. [NO_OF_OGs]`

              *i.e. For:*
              Camp Name: AVENGERS.
              Houses: THOR
                      HULK
                      IRONMAN
              3 OGs per house

              *Enter:*
              `/new AVENGERS THOR HULK IRONMAN 3`

              HEREDOC
    
$delete_message = <<~HEREDOC
              *WARNING! ATHENA WILL EAT THIS SCOREBOARD..

              To confirm delete, please enter the name of the scoreboard in this form in CAPS:*

              `/DELETE [BOARD_NAME]`
              HEREDOC

$help_message = <<~HEREDOC
              *Usage:*

              /start - View this message.
              /edit - Modify scoreboards.
              /new - Create a new scoreboard.
              /about - Learn more about Athena.

              HEREDOC

$about_message = <<~HEREDOC
              *Athena keeps track of scores. 
              She is sculpted from Ruby and served by MongodDB.
              
              Found a bug? Flag an issue in her repo below!*
              
              _Athena is a work in progress so please be patient when
              using the bot!_

              View Athena's source code here:
              https://github.com/Carrein/AthenaBot
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
      reply_markup: new_markup,
      parse_mode: "Markdown"
      )
    else
      bot.api.send_message(
      chat_id: new_message.from.id,
      text: new_text,
      reply_markup: new_markup,
      parse_mode: "Markdown"
      )
    end
  rescue Telegram::Bot::Exceptions::ResponseError => e
  end
end

#Checks if given arguments are valid to create a board.
def check(args)
  args.length <= 4 || !args[-1].numeric? || args[-1].to_i <= 0 ? false : true
end

#Generates a new board given a set of argument.
def new_board(args, identity)
  #Open connection to database.
  client = Mongo::Client.new([$ip_addr], :database => "camp")

  #Check if document exists.
  if client[:doc].find({"name": args[1].upcase}).count() > 0
    "*Sorry, this scoreboard name exists. Please try again.*" 
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
    "*Success!\nBoard details as follows:*\n #{pretty_print(doc)}"
  end
end

#Print out all tasks available.
def tasks(var)
  kb = [
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "Add points." , callback_data: "p_#{var}"),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "View current scores." , callback_data: "s_#{var}"),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "View log history." , callback_data: "l_#{var}"),    
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "Add an admin." , callback_data: "a_#{var}"),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "Remove an admin." , callback_data: "r_#{var}"),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: "Delete this scoreboard." , callback_data: "d_#{var}")
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
  if kb.length > 0
    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
  else
    return false
  end
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
      result = "*User already exists. Please try again.*"
    else
      client[:doc].update_one({"name": var }, {"$push" => {"admins" => contact.user_id}})
      client[:log].update_one({"name": var }, {"$push" => {"log" => "#{identity.from.first_name} added #{contact.first_name}."}})
      result = "*Athena puts the new administrator in charge. Good luck.*"
    end
  else
    if client[:doc].find({"name": var, "admins": contact.user_id}).count > 0
      client[:doc].update_one({"name": var }, {"$pull" => {"admins" => contact.user_id}})
      client[:log].update_one({"name": var }, {"$push" => {"log" => "#{identity.from.first_name} removed #{contact.first_name}."}})
      result = "*Athena drags the helpless administrator away. Goodbye.*"
    else
      result = "*User does not exist. Please try again.*"
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
        kb << Telegram::Bot::Types::InlineKeyboardButton.new(text: "#{i} ⇾ #{o}", callback_data: value)
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

      #-d truncate, for adding scores.
      when /^[-\d].*/
        #Split TODO.
        var = m.data.split("_")
        add(m, var)
        print(m, "*Athena takes a marker and rewrites the scoreboard!*", nil, true)
        print(m, view("s_"), nil, true)
      #c truncate, after choosing scoreboard.
      
      when /^c.*/
        #Truncate identifier.
        var = m.data[2..-1]
        print(m, "*Okay, what would you like Athena to do?*", tasks(var), true)

      #o truncate, for choosing points.
      when /^o.*/
        var = m.data[2..-1]
        print(m, "*How many points to add?*", points(var), true)

      #p truncate, for choosing og/house.
      when /^p.*/
        var = m.data[2..-1]
        print(m, "*Pick an OG or a house.*", house(var), true)

      #s/l truncate, for viewing scores/logs.
      when /^[sl].*/
        print(m, view(m.data), nil, true)

      #a/r truncate, for adding/removing admins.
      when /^[ar].*/
        print(m, "*Okay, forward the contact you would like to remove/add to Athena.*", nil, true)
        bot.listen do |n|
          case n
          when Telegram::Bot::Types::Message
            if n.contact
              if !n.contact.user_id.nil?
                print(m, admin(m, m.data, n.contact))
                break
              else
                print(m, "*Sorry, please ensure the contact has Telegram and a country code (+65) added.*")             
                break
              end
            else
              print(m, "*Athena does not recognize that command. Say what?*")
              break
            end
          end
        end
      #nested d truncate, for removing scoreboards.
      when /^d.*/
        var = m.data[2..-1]
        print(m, $delete_message, nil, true)
        bot.listen do |n|
          case n
          when Telegram::Bot::Types::Message
            case n.text
            when "/DELETE #{var}"
              print(m, "*No. of document deleted: #{delete(var)}*")
              break
            else
              print(m, "*Name entered incorrectly, Athena leaves the board alone..*")
              break
            end
          end
        end
      else
        print(m, "*Something in Athena just froze! Please contact the administrator.*", nil, true)
      end
    when Telegram::Bot::Types::Message
      case m.text
      when /^\/start/
        print(m, $help_message)
      when /^\/about/
        print(m, $about_message)
      when /^\/edit/
        #Shows all available collections associated with this account.
        if(collections(m))
          print(m, "*Athena pulls up a stack of manila folders, which scoreboard would you like to edit?*", collections(m))
        else
          print(m, "*Athena looks into the folders and finds... nothing. Create a new scoreboard by using:* `/new`")
        end
      when /^\/new.*/
        new_message = m.text.split
        #Splits message text for checking.
        if check(new_message)
          print(m, "*Okay, Athena is searching for an empty scoreboard..*")
          print(m, new_board(new_message, m))
        else
          print(m, $error_message)
        end
      else
        print(m, "*Athena does not recognize that command. Say what?*")
      end
    end
  end
end