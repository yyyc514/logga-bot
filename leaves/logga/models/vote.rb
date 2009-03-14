class Vote < ActiveRecord::Base
  belongs_to :person
  belongs_to :other_person, :class_name => "Person"
end
