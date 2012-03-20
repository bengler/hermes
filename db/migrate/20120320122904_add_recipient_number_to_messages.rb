class AddRecipientNumberToMessages < ActiveRecord::Migration

  def self.up
    add_column :messages, :recipient_number, :text
  end

  def self.down
    remove_column :messages, :recipient_number
  end

end