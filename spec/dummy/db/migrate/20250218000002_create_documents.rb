# frozen_string_literal: true

class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.string :title
      t.text :content
      t.boolean :public, default: false
      t.boolean :archived, default: false

      t.timestamps
    end
  end
end
