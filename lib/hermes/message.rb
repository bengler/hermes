module Hermes
  class Message < ActiveRecord::Base

    validates :realm, :presence => {}
    validates :vendor_id, :presence => {}
    validates :status, :presence => {}

  end
end