class CreateScores < ActiveRecord::Migration
  def change
    create_table :scores do |t|
      t.references :student, index: true
      t.references :course, index: true
      t.integer :grade

      t.timestamps null: false
    end
    add_foreign_key :scores, :students
    add_foreign_key :scores, :courses
  end
end
