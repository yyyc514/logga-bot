# Controller for the logga leaf.
require 'lookup'
$LOAD_PATH.unshift(File.join(AL_ROOT,"leaves/logga/lib"))
require 'channel_events'
require 'api_lookups'

class Controller < Autumn::Leaf

  include ChannelEvents
  include ApiLookups

  THRESHOLD = 3
  
  before_filter :check_for_new_day
  
  def did_start_up
  end
      
  def who_command(stem, sender, reply_to, msg)
    if authorized?(sender[:nick])
      person = Person.find_by_name(msg.strip)
      if person
        unless person.chats.first.nil?
          stem.message("#{msg} has been around since #{person.chats.first(:order => "created_at ASC").created_at}")
        end
        stem.message("#{msg}: thanked #{person.thanks_count} time(s)", sender[:nick])
        unless person.notes.blank?
          stem.message("Notes for #{msg}: #{person.notes}", sender[:nick])
        end
      else
        stem.message("Couldn't find anyone named `#{msg.strip}`.", sender[:nick])
      end
    end
  end

  def gitlog_command(stem, sender, reply_to, msg)
    `git log -1`.split("\n").first
  end

  def tip_command(stem, sender, reply_to, command, options={})
    return unless authorized?(sender[:nick])
    if tip = Tip.find_by_command(command.strip) 
      tip.text.gsub!("{nick}", sender[:nick])
      message = tip.text
      message = "#{options[:directed_at]}: #{message}" if options[:directed_at]
      find_or_create_person("logga").chats.create(:channel => reply_to, :message => message, :message_type => "message")
      stem.message(message, reply_to)          
    else
      stem.message("I could not find that command. If you really want that command, go to http://rails.loglibrary.com/tips/new?command=#{command} and create it!", sender[:nick])
    end    
  end
  
  def join_command(stem, sender, reply_to, msg)
    join_channel(msg) if authorized?(sender[:nick])
  end

  def part_command(stem, sender, reply_to, msg)
    leave_channel(msg) if authorized?(sender[:nick])
  end
  
  def help_command(stem, sender, reply_to, msg)
    if authorized?(sender[:nick])
      if msg.nil?
        stem.message("A list of all commands can be found at http://rails.loglibrary.com/tips", sender[:nick])
      else
        comnand = msg.split(" ")[1]
        if tip = Tip.find_by_command(command)
          stem.message(" #{tip.command}: #{tip.description} - #{tip.text}", sender[:nick])
        else  
          stem.message("I could not find that command. If you really want that command, go to http://rails.loglibrary.com/tips/new?command=#{command} and create it!", sender[:nick])
        end
      end
    end
  end
  
  def google_command(stem, sender, reply_to, msg, opts={})
    search("http://www.google.com/search", stem, sender, msg, reply_to, opts)
  end
  
  alias :g_command :google_command 
  
  def gg_command(stem, sender, reply_to, msg, opts={})
    search("http://www.letmegooglethatforyou.com/", stem, sender, msg, reply_to, opts)
  end
  
  def railscast_command(stem, sender, reply_to, msg, opts={})
    search("http://railscasts.com/episodes", stem, sender, msg, reply_to, opts, "search")
  end
  
  def githubs_command(stem, sender, reply_to, msg, opts={})
    search("http://github.com/search", stem, sender, msg, reply_to, opts)
  end
  
  def github_command(stem, sender, reply_to, msg, opts={})
    parts = msg.split(" ")
    message = "http://github.com/#{parts[0]}/#{parts[1]}/tree/#{parts[2].nil? ? 'master' : parts[2]}"
    message += "/#{parts[3..-1].join("/")}" if !parts[3].nil?
    direct_at(stem, reply_to, message, opts[:directed_at])
  end
  
  private
  
  def direct_at(stem, reply_to, message, who=nil)
    if who
      message = who + ": #{message}" 
      stem.message(message, reply_to)
    else
      return message
    end
  end
  
  def search(host, stem, sender, msg, reply_to, opts, query_parameter="q")
    message = "#{host}?#{query_parameter}=#{msg.split(" ").join("+")}"
    direct_at(stem, reply_to, message, opts[:directed_at])
  end
  
  # I, Robot.
  
  def i_am_a_bot
    ["I am a bot! Please do not direct messages at me!",
     "FYI I am a bot.",
     "Please go away. I'm only a bot.",
     "I am not a real person.",
     "No I can't help you.",
     "Wasn't it obvious I was a bot?",
     "I am not a werewolf; I am a bot.",
     "I'm botlicious.",
     "Congratulations! You've managed to message a bot.",
     "I am a bot. Your next greatest discovery will be that the sky is, in fact, blue."     
     ].rand
  end
  
  # Who's there?
  
  def authorized?(nick)
    User.find_by_login(nick.downcase)
  end

  def check_for_new_day_filter(host, stem, sender, msg, reply_to, opts)
    @day = Day.find_or_create_by_date(Date.today) if @today!=Date.today
    @today = Date.today
    @day.increment!("chats_count")
  end

  def find_or_create_person(name)
    Person.find_or_create_by_name(name)
  end

  def find_or_create_hostname(hostname, person)
    person.hostnames << Hostname.find_or_create_by_hostname(hostname)
  end

  def did_receive_channel_message(stem, sender, channel, message) 
     person = find_or_create_person(sender[:nick])
     # Does this message clearly reference another person as the first word.
     other_person = /^(.*?)[:|,]/.match(message)
     other_person = Person.find_by_name(other_person[1]) unless other_person.nil?
     # try to match a non-existent command which might be a tip
     if m = /^(([^:]+):)?\s?!([^\s]+)\s?(.*)?/.match(message)
       cmd_sym = "#{m[3]}_command".to_sym
       # if we don't respond to this command then it's likely a tip
       if respond_to?(cmd_sym)
         if !m[2].nil?
           send(cmd_sym, stem, sender, channel, m[4], { :directed_at => m[2] })
         end
       else
         tip_command(stem,sender,channel,m[3], { :directed_at => m[2] })
       end
     end

     if m = /^(([^:]+):)?\s?@(.+)/.match(message)
       send(:lookup_command, stem, sender, channel, m[3], { :directed_at => m[2] })
     end

     # Don't speak to me!
     if message.match(/^logga[:|,]/)
       stem.message(i_am_a_bot, sender[:nick])
     end

     # Log Chat Line
     chat = person.chats.create(:channel => channel, :message => message, :message_type => "message", :other_person => other_person)

     ## Did the person thank another person?
     # Someone was called "a"
     words = message.split(" ") - ["a"]
     words.each { |x| x.gsub!(/[:,]/,"") }
     # Can't be thanked if count < 100...
     # stops stuff like "why thanks Radar" coming up for chatter "why" & "Radar" instead of just "Radar"
     people = Person.find_all_by_name(words, :conditions => "chats_count > 100")

     # Allow voting for multiple people.
     if /(thank|thx|props|kudos|big ups|10x|cheers)/i.match(chat.message) && chat.message.split(" ").size != 1 && !people.blank?
       for person in (people - [chat.person] - ["anathematic"])
         person.votes.create(:chat => chat, :person => chat.person)
       end
     end
   end

  
    
end
