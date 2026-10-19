import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PERMISSIONS_KEY } from './permissions.decorator';

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredPermissions = this.reflector.getAllAndOverride<string[]>(
      PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );

    // If no permission metadata defined, allow access for authenticated user
    if (!requiredPermissions || requiredPermissions.length === 0) {
      return true;
    }

    const request = context.switchToHttp().getRequest();
    const user = request.user;

    if (!user) {
      throw new ForbiddenException('User context missing');
    }

    // SuperAdmin or storeadmin role has full bypass access
    if (
      user.isSuperAdmin === true ||
      (Array.isArray(user.appWorks) && user.appWorks.includes('storeadmin'))
    ) {
      return true;
    }

    const userPermissions: string[] = Array.isArray(user.appWorks)
      ? user.appWorks
      : [];

    // If user has no permissions assigned, strictly block access to guarded endpoints
    if (userPermissions.length === 0) {
      throw new ForbiddenException(
        `Insufficient permissions. Required: ${requiredPermissions.join(' or ')}`,
      );
    }

    // Strict and accurate permission match
    const hasPermission = requiredPermissions.some((reqPerm) => {
      // 1. Direct exact match (e.g. 'storeitemview', 'storreceiveadd', 'storissueapprove')
      if (userPermissions.includes(reqPerm)) return true;

      // 2. Wildcard admin permission
      if (userPermissions.includes('*')) return true;

      // 3. Permission alias mappings (e.g., storeimportData <=> storeimport)
      if (reqPerm === 'storeimport' && userPermissions.includes('storeimportData')) return true;
      if (reqPerm === 'storeimportData' && userPermissions.includes('storeimport')) return true;

      return false;
    });

    if (!hasPermission) {
      throw new ForbiddenException(
        `Insufficient permissions. Required: ${requiredPermissions.join(' or ')}`,
      );
    }

    return true;
  }
}
