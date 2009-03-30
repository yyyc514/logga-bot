# Controller for the logga leaf.
require 'lookup'

class Controller < Autumn::Leaf

  THRESHOLD = 3
  
  before_filter :check_for_new_day
  
  def did_start_up
  end
      
  def who_command(stem, sender, reply_to, msg)
    if authorized?(sender[:nick])
      person = Person.find_by_name(msg.strip)
      if person
        stem.message("#{msg} has been around since #{person.chats.first(:order => "created_at ASC").created_at}")
        stem.message("#{msg}: thanked #{person.thanks_count} time(s)", sender[:nick])
        unless person.notes.blank?
          stem.message("Notes for #{msg}: #{person.notes}", sender[:nick])
        end
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
  
  def update_api_command(stem, sender, reply_to, msg)
    return unless authorized?(sender[:nick])
    stem.message("Updating API index", sender[:nick])
    APILookup.update
    stem.message("Updated API index! Use the !lookup <method> or !lookup <class> <method> to find what you're after", sender[:nick])
    return nil
  end
    
  def lookup_command(stem, sender, reply_to, msg, opts={})
    parts = msg.split(" ")[0..-1].map { |a| a.split("#") }.flatten!
    
    results=APILookup.search(msg)
    opts.merge!(:stem => stem, :reply_to => reply_to)
    show_api_results(results,msg, opts)
  end
  
  def show_api_results(results,search_string, opts={})
    if results.empty?
      opts[:stem].message "I could find no API results matching `#{search_string}`.", opts[:reply_to]
    elsif results.size == 1
      display_api_url(results.first, opts)
    elsif results.size <= THRESHOLD
      results.each_with_index do |result, i|
        display_api_url(result, opts.merge(:number => i+1))
      end
    else
      opts[:stem].message "Please be more specific, we found #{results.size} results (threshold is #{THRESHOLD}).", opts[:reply_to]
    end
  end
  
  def display_api_url(result, opts={})
    s = opts[:number] ? opts[:number].to_s + ". " : ""
    # if we're a method then show the constant in parans
    s += "(#{result.constant.name}) " if result.is_a?(APILookup::Entry)
    s += "#{result.name} #{result.url}"
    opts[:stem].message("#{opts[:directed_at] ? opts[:directed_at] + ":"  : ''} #{s}", opts[:reply_to])
  end
  
  def for_sql(string)
    string
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
     
     # Don't speak to me!
     if message.match(/^logga[:|,]/)
       stem.message(i_am_a_bot, sender[:nick])
     end

     # Log Chat Line
     chat = person.chats.create(:channel => channel, :message => message, :message_type => "message", :other_person => other_person)

     ## Did the person thank another person?
     # Someone was called "a"
     words = message.split(" ") - ["a"]
     people = []
     for word in words
       word = word.gsub(":", "")
       word = word.gsub(",", "")
       # Can't be thanked if count < 100...
       # stops stuff like "why thanks Radar" coming up for chatter "why" & "Radar" instead of just "Radar"
       people << Person.find_by_name(word, :conditions => "chats_count > 100")
     end

     # Allow voting for multiple people.
     people = people.compact!
     if /(thank|thx|props|kudos|big ups|10x|cheers)/i.match(chat.message) && chat.message.split(" ").size != 1 && !people.blank?
       for person in (people - [chat.person] - ["anathematic"])
         person.votes.create(:chat => chat, :person => chat.person)
       end
     end
   end

   def someone_did_join_channel(stem, sender, channel)
     return if sender.nil?
     person = find_or_create_person(sender[:nick])
     find_or_create_hostname(sender[:host], person)
     person.chats.create(:channel => channel, :message_type => "join")  unless sender[:nick] == "logga"
   end

   def someone_did_leave_channel(stem, sender, channel)
     person = find_or_create_person(sender[:nick])
     find_or_create_hostname(sender[:host], person)
     person.chats.create(:channel => channel, :message_type => "part")
   end

   def someone_did_quit(stem, sender, message)
     return if sender.nil?
     person = find_or_create_person(sender[:nick])
     find_or_create_hostname(sender[:host], person)
     person.chats.create(:channel => nil, :message => message, :message_type => "quit")
   end

   def nick_did_change(stem, person, nick)
     return if person.nil?
     old_person = person
     person = find_or_create_person(person[:nick])
     other_person = find_or_create_person(nick)
     find_or_create_hostname(old_person[:host], person)
     find_or_create_hostname(old_person[:host], other_person)
     person.chats.create(:channel => nil, :person => person, :message_type => "nick-change", :other_person => other_person)
   end

   def someone_did_kick(stem, kicker, channel, victim, message)
     person = find_or_create_person(kicker[:nick])
     find_or_create_hostname(kicker[:host], person)
     other_person = find_or_create_person(victim)
     person.chats.create(:channel => channel, :other_person => other_person, :message => message, :message_type => "kick")
   end

   def someone_did_change_topic(stem, person, channel, topic)
     person = find_or_create_person(person[:nick])
     person.chats.create(:channel => channel, :message => topic, :message_type => "topic")
   end

   def someone_did_gain_privilege(stem, channel, nick, privilege, bestower)
     person = find_or_create_person(nick)
     other_person = find_or_create_person(bestower[:nick])
     person.chats.create(:channel => channel, :message => privilege.to_s, :other_person => other_person, :message_type => "gained_privilege")
   end

   def someone_did_lose_privilege(stem, channel, nick, privilege, bestower)
     person = find_or_create_person(nick)
     other_person = find_or_create_person(bestower[:nick])
     person.chats.create(:channel => channel, :message => privilege.to_s, :other_person => other_person, :message_type => "lost_privilege")
   end

   def channel_did_gain_property(stem, channel, property, argument, bestower)
     person = find_or_create_person(bestower[:nick])
     person.chats.create(:channel => channel, :message => "#{argument[:mode]} #{argument[:parameter]}", :message_type => "mode")
   end
 
  alias_method :channel_did_lose_property, :channel_did_gain_property
  
    
end
