class CreateMessages < ActiveRecord::Migration

  def self.up
    create_table :messages do |t|
      t.timestamp :created_at
      t.timestamp :updated_at
      t.text :vendor_id, :null => false
      t.text :realm, :null => false
      t.text :status, :null => false
    end
  end

  def self.down
    drop_table :messages
  end

end