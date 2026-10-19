import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { User } from '../auth/schema/auth.schema.js';
import { RegisterDto } from '../auth/dto/register.dto.js';
import { CreateAuthDto } from '../auth/dto/create-auth.dto.js';
import { UpdateAuthDto } from '../auth/dto/update-auth.dto.js';
import { UpdateRegistorDto } from '../auth/dto/update-register.dto.js';
import { ResetPasswordDto } from '../auth/dto/reset-password.dto.js';
import bcrypt from 'bcryptjs';
import { CreateDivisionDto } from '../auth/dto/create-division.dto.js';
import { Division } from '../auth/schema/division.schema.js';

@Injectable()
export class UserService {
  constructor(
    @InjectModel(User.name, 'auth')
    private userSchema: Model<User>,

    @InjectModel(Division.name, 'auth')
    private readonly divisionModel: Model<Division>,
  ) {}

  async findUsersWithDivisionMap(
    userIds: string[],
  ): Promise<Map<string, { name: string; department: string }>> {
    const map = new Map<string, { name: string; department: string }>();
    if (!userIds || userIds.length === 0) return map;

    try {
      const cleanIds = Array.from(
        new Set(
          userIds
            .map((id) => String(id || '').trim())
            .filter((id) => Boolean(id)),
        ),
      );
      if (cleanIds.length === 0) return map;

      const validOids = cleanIds
        .filter((id) => Types.ObjectId.isValid(id))
        .map((id) => new Types.ObjectId(id));

      const queryConditions: any[] = [{ _id: { $in: cleanIds } }];
      if (validOids.length > 0) {
        queryConditions.push({ _id: { $in: validOids } });
      }

      const [users, allDivs] = await Promise.all([
        this.userSchema
          .find({ $or: queryConditions })
          .populate('divisionIds')
          .lean()
          .exec(),
        this.divisionModel.find().lean().exec().catch(() => []),
      ]);

      const divNameMap = new Map<string, string>();
      for (const d of allDivs as any[]) {
        if (d?.divisionName) {
          divNameMap.set(String(d._id), String(d.divisionName).trim());
        }
      }

      for (const user of users) {
        let dept = (user as any).departmentName || '';
        if (
          !dept &&
          Array.isArray((user as any).divisionIds) &&
          (user as any).divisionIds.length > 0
        ) {
          dept = (user as any).divisionIds
            .map((d: any) => {
              if (typeof d === 'object' && d !== null) {
                return (
                  d.divisionName ||
                  d.name ||
                  divNameMap.get(String(d._id)) ||
                  ''
                );
              }
              const str = String(d || '').trim();
              return divNameMap.get(str) || '';
            })
            .filter(Boolean)
            .join(', ');
        }

        if (!dept || /^[0-9a-fA-F]{24}$/.test(dept.trim())) {
          dept = divNameMap.get(dept.trim()) || 'General Operations';
        }

        const name = user.name || 'Unknown';
        map.set(String(user._id), { name, department: dept });
      }
    } catch (err) {
      console.error('[UserService] findUsersWithDivisionMap error:', err);
    }

    return map;
  }

  async findByPhoneNo(phoneNumber: string) {
    return this.userSchema.findOne({ phoneNumber }).exec();
  }

  async findAll() {
    return this.userSchema.find().exec();
  }

  async findById(id: string) {
    return this.userSchema.findById(id).exec();
  }

  async findOne(id: string) {
    return this.userSchema.findOne({ _id: id }).exec();
  }

  async findByEmail(email: string) {
    return this.userSchema.findOne({ email }).exec();
  }

  async createAuth(data: RegisterDto) {
    const doc: User = new this.userSchema(data);
    await doc.save();
    return doc;
  }

  async updateAuth(data: UpdateRegistorDto) {
    const doc: User | null = await this.userSchema.findByIdAndUpdate(
      data.id,
      data,
    );
    return doc;
  }

  async findUserPaged(body: any) {
    const page = Math.max(1, Number(body?.page ?? 1));
    const limit = Math.min(200, Math.max(1, Number(body?.limit ?? 12)));
    const skip = (page - 1) * limit;

    const qText = String(body?.q ?? '').trim();
    const field = String(body?.field ?? 'all'); // all | name | email | phone

    // sort
    const sortStr = String(body?.sort ?? '-createdAt');
    const dir = sortStr.startsWith('-') ? -1 : 1;
    const fieldName = sortStr.replace(/^-/, '') || 'createdAt';
    const sort: Record<string, 1 | -1> = { [fieldName]: dir };

    // filter
    const filter: any = {};
    if (qText) {
      const rx = { $regex: qText, $options: 'i' };
      if (field === 'name') filter.name = rx;
      else if (field === 'email') filter.email = rx;
      else if (field === 'phone') filter.phoneNumber = rx;
      else {
        filter.$or = [{ name: rx }, { email: rx }, { phoneNumber: rx }];
      }
    }

    const project = {
      name: 1,
      email: 1,
      phoneNumber: 1,
      isActive: 1,
      isSuperAdmin: 1,
      createdAt: 1,
      updatedAt: 1,
    };

    const [rows, total] = await Promise.all([
      this.userSchema
        .find(filter)
        .sort(sort)
        .skip(skip)
        .limit(limit)
        // .select(project)
        .lean(),
      this.userSchema.countDocuments(filter),
    ]);

    return {
      rows: rows.map((u: any) => ({
        ...u,
        _id: String(u._id ?? ''), // normalize id to FE shape if needed
      })),
      total,
      page,
      limit,
    };
  }

  async updaterResetPwd(data: ResetPasswordDto) {
    const hash = await bcrypt.hash(data.newPassword, 10);
    const doc: User | null = await this.userSchema.findByIdAndUpdate(
      data.userId,
      {
        $set: {
          password: hash,
        },
      },
    );
    return doc;
  }

  async deleteAuth(id: string) {
    const doc: User | null = await this.userSchema.findByIdAndDelete(id);
    return doc;
  }

  // async createAdmin(data: CreateAuthDto) {
  //   const doc: User = new this.userSchema(data);
  //   await doc.save();
  //   return doc;
  // }

  // async update(data: UpdateAuthDto) {
  //   const doc: User = new this.userSchema(data);
  //   return doc;
  // }

  async createDivision(dto: CreateDivisionDto) {
    const divisionName = dto.divisionName.trim();

    try {
      const created = await this.divisionModel.create({
        divisionName,
        remark: dto.remark ?? '',
      });
      return created;
    } catch (e: any) {
      // Mongo duplicate key error
      if (e?.code === 11000) {
        throw new BadRequestException('division_already_exists');
      }
      throw e;
    }
  }

  async findAllDivision() {
    return this.divisionModel
      .find({ isActive: true })
      .sort({ divisionName: 1 })
      .lean();
  }

  async checkDivision(divisions: any) {
    const existing = await this.divisionModel.countDocuments({
      _id: { $in: divisions },
    });

    if (existing !== divisions.length) {
      return false;
    }

    return true;
  }
}
