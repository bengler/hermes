class RenameProfileBackToRealm < ActiveRecord::Migration
  def self.up
    rename_column :messages, :profile, :realm
  end

  def self.down
    rename_column :messages, :realm, :profile
  end
end
