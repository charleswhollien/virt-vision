class CreateHosts < ActiveRecord::Migration[8.0]
  def change
    create_table :hosts do |t|
      t.string :name
      t.string :hostname
      t.string :connection_uri
      t.string :ssh_user
      t.string :ssh_key_path
      t.text :encrypted_ssh_key
      t.string :status
      t.datetime :last_polled_at
      t.integer :cpu_total
      t.integer :memory_total

      t.timestamps
    end
    add_index :hosts, :name, unique: true
  end
end
