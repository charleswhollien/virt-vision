class CreateAlerts < ActiveRecord::Migration[8.0]
  def change
    create_table :alerts do |t|
      t.string :name
      t.string :condition_type
      t.decimal :threshold
      t.boolean :enabled, default: true
      t.string :notification_channel
      t.references :host, null: true, foreign_key: true
      t.references :vm, null: true, foreign_key: true

      t.timestamps
    end
  end
end
