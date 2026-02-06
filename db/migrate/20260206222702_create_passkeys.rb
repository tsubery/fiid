class CreatePasskeys < ActiveRecord::Migration[8.0]
  def change
    create_table :passkeys do |t|
      t.string :label, null: false
      t.string :external_id, null: false
      t.string :public_key, null: false
      t.bigint :sign_count, null: false, default: 0

      t.timestamps
    end

    add_index :passkeys, :external_id, unique: true
  end
end
