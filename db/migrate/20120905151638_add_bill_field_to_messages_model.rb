class AddBillFieldToMessagesModel < ActiveRecord::Migration
  def self.up
    add_column :messages, :bill, :text
  end

  def self.down
    remove_column :messages, :bill
  end
end
