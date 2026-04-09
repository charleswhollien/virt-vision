class CreateVms < ActiveRecord::Migration[8.0]
  def change
    create_table :vms do |t|
      t.string :uuid
      t.string :name
      t.references :host, null: false, foreign_key: true
      t.string :status
      t.integer :cpu_count
      t.integer :memory_mb
      t.text :disk_info
      t.text :network_info
      t.datetime :last_updated_at

      t.timestamps
    end
    add_index :vms, :uuid, unique: true
  end
end
