// สร้าง database และ user สำหรับ app
db = db.getSiblingDB('myapp');

// สร้าง user สำหรับ application
db.createUser({
  user: 'appuser',
  pwd: 'apppass123',
  roles: [
    {
      role: 'readWrite',
      db: 'myapp'
    }
  ]
});

// สร้างข้อมูลตัวอย่าง
db.users.insertMany([
  {
    name: 'John Doe',
    email: 'john@example.com',
    age: 25,
    city: 'Bangkok',
    createdAt: new Date()
  },
  {
    name: 'Jane Smith', 
    email: 'jane@example.com',
    age: 30,
    city: 'Chiang Mai',
    createdAt: new Date()
  }
]);

print('✅ Database initialized with sample data');