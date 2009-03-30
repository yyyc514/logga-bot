module Logga
  module ChannelEvents

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
end