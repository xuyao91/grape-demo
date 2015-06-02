class CreateStudents < ActiveRecord::Migration
  def change
    create_table :students do |t|
      t.string :name
      t.integer :age
      t.integer :gender
      t.string :mobile

      t.timestamps null: false
    end
  end
end
