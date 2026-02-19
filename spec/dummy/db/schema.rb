# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_02_19_000001) do
  create_table "document_collaboration_permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "document_collaboration_id", null: false
    t.string "permission", null: false
    t.datetime "updated_at", null: false
    t.index ["document_collaboration_id", "permission"], name: "index_doc_collab_perms_on_collab_and_permission", unique: true
    t.index ["document_collaboration_id"], name: "idx_on_document_collaboration_id_b6927bac13"
  end

  create_table "document_collaborations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "document_id", null: false
    t.text "permissions"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["document_id", "user_id"], name: "index_document_collaborations_on_document_id_and_user_id", unique: true
    t.index ["document_id"], name: "index_document_collaborations_on_document_id"
    t.index ["user_id"], name: "index_document_collaborations_on_user_id"
  end

  create_table "documents", force: :cascade do |t|
    t.boolean "archived", default: false
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "owner_id", null: false
    t.boolean "public", default: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_documents_on_owner_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "document_collaboration_permissions", "document_collaborations"
  add_foreign_key "document_collaborations", "documents"
  add_foreign_key "document_collaborations", "users"
  add_foreign_key "documents", "users", column: "owner_id"
end
