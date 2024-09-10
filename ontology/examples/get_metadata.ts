import { DataSource } from "typeorm"
@Entity({ name: 'customer' })
class CustomerEntity implements Customer.Model {
  @PrimaryColumn()
  id!: string;
  @Column({ nullable: true, unique: true })
  referenceId!: string | null;
  @Column()
  name!: string;
  @Column()
  email!: string;
  @Column({ nullable: true })
  phone!: string | null;
}
async function test() {
  const dataSource = new DataSource({
    // ...
    entities: [CustomerEntity] // Reference to the customer entity class
  });
  await dataSource.initialie();
  console.log(dataSource.getMetadata(CustomerEntity));
}