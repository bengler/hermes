class CreateKindField < ActiveRecord::Migration
  def self.up
    add_column :messages, :kind, :text, :null => false
    Hermes::Message.update_all ["kind = ?", 'sms']
  end

  def self.down
    remove_column :messages, :kind
  end
end
