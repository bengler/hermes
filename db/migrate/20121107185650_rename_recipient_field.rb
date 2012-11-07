class RenameRecipientField < ActiveRecord::Migration
  def self.up
    rename_column :messages, :recipient_number, :recipient
  end

  def self.down
    rename_column :messages, :recipient, :recipient_number
  end
end
