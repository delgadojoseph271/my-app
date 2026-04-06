# Arreglar commitlint en Windows + OneDrive + Husky

## Problema

Al ejecutar `git commit -m "tipo: mensaje"` aparece el error:

```
Error: ENOENT: no such file or directory, open '...\my-app\%1'
husky - commit-msg script failed (code 1)
```

O también:

```
"commitlint" no se reconoce como un comando interno o externo
```

### Causas

1. **OneDrive + WSL**: Las rutas se transforman incorrectamente (`/mnt/c/...`)
2. **PowerShell vs Bash**: El parámetro `$1` no funciona correctamente en el hook
3. **Rutas relativas**: Husky pasa argumentos que no se resuelven bien

---

## Solución

### 1. Instalar dependencias

```bash
npm install -D @commitlint/cli @commitlint/config-conventional husky
npx husky init
```

### 2. Configurar commitlint

Crear `commitlint.config.js`:

```javascript
module.exports = {
  extends: ['@commitlint/config-conventional']
};
```

### 3. Arreglar el hook `.husky/commit-msg`

El archivo por defecto tiene:

```bash
npx --no-install commitlint --edit "$1"
```

Cambiar a:

```bash
node node_modules/@commitlint/cli/lib/cli.js --color --edit .git/COMMIT_EDITMSG
```

**Por qué funciona:** Usa la ruta relativa directa al archivo de mensaje de commit en lugar del parámetro `$1` que falla en Windows/PowerShell.

### 4. Verificar que funcione

```bash
git commit -m "feat(auth): agrega JWT"
```

Debería mostrar:

```
[feature/auth-jwt 12ffee9] feat(auth): agrega JWT
```

---

## Tips adicionales

| Problema | Solución |
|----------|----------|
| OneDrive lento | Mover proyecto fuera de OneDrive |
| WSL conflicto | Usar git desde PowerShell/Windows |
| Commit sin hook | `git commit --no-verify -m "mensaje"` |

---

## Conventional Commits

```
tipo(alcance): descripción

feat(auth): agregar login con JWT
fix(users): corregir validación de email
chore(deps): actualizar dependencias
```

### Tipos válidos

| Tipo | Cuándo usarlo |
| --- | --- |
| `feat` | Nueva funcionalidad |
| `fix` | Corrección de bug |
| `docs` | Solo documentación |
| `chore` | Mantenimiento, dependencias |
| `refactor` | Refactorización sin cambio de comportamiento |
| `test` | Agregar o corregir tests |
| `ci` | Cambios en CI/CD |
| `style` | Formato, espacios |
