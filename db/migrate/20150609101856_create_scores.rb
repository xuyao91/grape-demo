class CreateScores < ActiveRecord::Migration
  def change
    create_table :scores do |t|
      t.integer :student_id, index: true
      t.integer :course_id, index: true
      t.integer :grade

      t.timestamps null: false
    end
  end
end
