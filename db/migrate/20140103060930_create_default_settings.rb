class CreateDefaultSettings < ActiveRecord::Migration
  def change
    create_table :default_settings do |t|
      t.string :name
      t.string :value
      t.boolean :status, :default => true

      t.timestamps
    end
  end
end
