class AddCallbackUrlToMessages < ActiveRecord::Migration

  def self.up
    add_column :messages, :callback_url, :text
  end

  def self.down
    remove_column :messages, :callback_url
  end

end
