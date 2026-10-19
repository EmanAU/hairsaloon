import Image from 'next/image';

export function BrandLogo({
  size = 36,
  className = 'brand-logo',
}: {
  size?: number;
  className?: string;
}) {
  return (
    <Image
      src="/trimmatrix_logo.png"
      alt="TrimMatrix"
      width={size}
      height={size}
      className={className}
      priority
    />
  );
}
